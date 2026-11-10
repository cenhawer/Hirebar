import Foundation
import HirebarDomain

private let log = Log(.ai)

@MainActor
public final class Controller {
    let targetRules: TargetRules
    lazy var executionGuard = ExecutionGuard(
        store: stores.executionState, alerts: TelegramExecutionAlerts(notifier: notifier, agents: stores.agents), rules: targetRules)
    var unsavedPauses: [AgentID: AgentPause] = [:]
    public let chat: ChatChannel
    public let notifier: Notifier
    public internal(set) var channel: ChannelSetup
    public weak var scheduler: Scheduler?
    public weak var jobRadar: JobRadar?
    public weak var freelanceRadar: FreelanceRadar?

    let clock: Clock
    let aiRunner: AIRunner
    let media: MediaRenderer
    public let stores: Repositories

    public init(stores: Repositories, adapters: EngineAdapters) {
        let resources = adapters.resources
        clock = adapters.clock
        aiRunner = adapters.aiRunner
        media = adapters.media
        targetRules = resources.targetRules
        commandParser = resources.commands.map(CommandParser.init)
        chat = adapters.chat
        self.stores = stores
        notifier = Notifier(chat: adapters.chat, desktop: adapters.desktop, config: stores.config, batches: stores.batches)
        channel = ChannelSetup(settings: resources.channel, chat: adapters.chat, configs: stores.config, clock: clock)
    }

    public var ai: AI { AI(settings: stores.config.load().aiEngine) }
    var prompts: AgentPrompts { AgentPrompts(stores: stores, ai: ai) }
    var commandParser: CommandParser?
    nonisolated static let noNewsMarker = "SIN_NOVEDADES"
    nonisolated static let maxRunSeconds: TimeInterval = 3600
    nonisolated static let authAlertEvery: TimeInterval = 3600

    public var onStatusChange: ((String) -> Void)?
    public private(set) var status = String(localized: "en espera")
    var queue: [(Batch, [BatchItem])] = []
    var running: AIRun?
    var runningBatch: String?
    var runningMode: Mode?
    var runningAccount: String?
    var runStarted: Date?
    var watchdog: ScheduledWork?
    var lastAuthAlert: Date?

    nonisolated static let watchdogInterval: TimeInterval = 60
    nonisolated static let recoveryDelay: TimeInterval = 5

    public var isIdle: Bool { running == nil && queue.isEmpty }
    public var runningAgent: AgentKind? { runningMode.map(AgentKind.owner) }

    public func start() {
        if watchdog == nil {
            watchdog = clock.every(Self.watchdogInterval, tolerance: 0) { [weak self] in self?.stopIfStuck() }
        }
        stores.workspace.prepare()
        chat.onMessage = { [weak self] message in self?.handle(message) }
        chat.onTokenStateChange = { [weak self] in self?.channel.tokenStateChanged() }
        chat.start()
        Task { @MainActor [weak self] in await self?.channel.completeMissingDetails() }
        clock.after(Self.recoveryDelay) { [weak self] in self?.recoverInterrupted() }
    }

    func setStatus(_ text: String) {
        status = text
        onStatusChange?(text)
    }

    var replies: ((String) -> Void)?
    var questions: ((String, [[(String, String)]]) -> Void)?

    func reply(_ text: String) {
        if let replies { replies(text) } else { notifier.tell(text) }
    }

    func askPerson(_ text: String, buttons: [[(String, String)]]) {
        if let questions {
            questions(text, buttons)
            return
        }
        guard notifier.canUseTelegram else {
            notifier.tell(text)
            return
        }
        chat.send(text, chatId: stores.config.load().chatId, buttons: buttons)
    }

    public func autoApprove(_ batch: Batch) {
        approve(batch, picks: [], approvedBy: .autoSend)
    }

    func approve(_ found: Batch?, picks: [Int], approvedBy: Approver = .person) {
        guard var batch = found else {
            reply(String(localized: "No tengo listas pendientes de las últimas 24 horas."))
            return
        }
        guard batch.status == .pending else {
            reply(String(localized: "Esa lista ya está \(batch.status.rawValue)."))
            return
        }
        let chosen =
            picks.isEmpty
            ? batch.items
            : picks.filter { $0 >= 1 && $0 <= batch.items.count }.map { batch.items[$0 - 1] }
        guard !chosen.isEmpty else {
            reply(String(localized: "Esos números no están en la lista (van del 1 al \(batch.items.count))."))
            return
        }
        guard let ready = approvedWithinQuota(chosen, from: batch, approvedBy: approvedBy) else { return }
        batch.status = .running
        batch.items = ready
        stores.batches.upsert(batch)
        stores.metrics.bump(batch.mode, "aprobados", ready.count)
        if let id = batch.messageId { chat.removeButtons(chatId: stores.config.load().chatId, messageId: id) }
        queue.append((batch, ready))
        if running == nil {
            runNext()
        } else {
            reply(String(localized: "Anotado: \(ai.capitalizedName) está terminando otra lista y sigue con esta."))
        }
    }

    public func runScheduled(_ mode: Mode, manual: Bool = false, account: String? = nil) {
        if mode == .linkedInDraft && account == nil {
            let today = Date()
            let accounts = stores.contentAccounts.enabled().filter { manual || $0.runs(on: today) }
            if accounts.isEmpty && manual {
                reply(String(localized: "No tienes cuentas de contenido prendidas. Agrégalas en Ajustes → Cuentas de contenido."))
            }
            for item in accounts { runScheduled(mode, manual: manual, account: item.id) }
            return
        }
        if Scheduler.isIdlePortalScan(mode, portals: stores.portals) {
            let agentName = stores.agents.load(AgentKind.owner(of: mode)).name
            if manual { reply(String(localized: "No tienes portales propios activos. Agrégalos en Ajustes → \(agentName).")) }
            return
        }
        let alreadyRunning = runningMode == mode && runningAccount == account
        if alreadyRunning || queue.contains(where: { $0.0.mode == mode && $0.0.account == account }) {
            if manual { reply(String(localized: "Eso ya está en curso.")) }
            return
        }
        let batch = Batch(mode: mode, status: .running, manual: manual, account: account)
        if TaskProfiles.profile(for: mode, account: stores.contentAccounts.find(account)).canAct {
            guard prepareScheduledExecution(batch, manual: manual) else { return }
        }
        stores.batches.upsert(batch)
        if manual && mode == .linkedInDraft {
            let ahead = queue.prefix { $0.0.mode == .linkedInDraft && $0.0.isManual }.count
            queue.insert((batch, []), at: ahead)
        } else {
            queue.append((batch, []))
        }
        let accountTitle = stores.contentAccounts.find(account)?.title ?? String(localized: "tu cuenta")
        if manual {
            switch mode {
            case .weeklyReport: reply(String(localized: "Preparando el informe semanal; te lo mando al terminar."))
            case .linkedInDraft:
                reply(
                    String(
                        localized: """
                            Armando la publicación para \(accountTitle) con sus imágenes; te la mando antes de publicar \
                            nada.
                            """)
                        + (running == nil ? "" : String(localized: " Empieza apenas termine lo que está corriendo ahora.")))
            case .linkedInPublish:
                reply(String(localized: "Publicando en \(accountTitle) la publicación que aprobaste; te confirmo al terminar."))
            case .followUp: reply(String(localized: "Revisando seguimientos ahora; te aviso si escribo a algún cliente."))
            case .prospectingSend: reply(String(localized: "Enviando los correos aprobados; te confirmo al terminar."))
            case .social: reply(String(localized: "Buscando vacantes publicadas en redes; te aviso si encuentro algo."))
            case .prospecting: reply(String(localized: "Buscando empresas y negocios para escribirles; te mando la lista al terminar."))
            case .profileUpdate: reply(String(localized: "Actualizando tu perfil y tus hojas de vida; te mando los PDF al terminar."))
            default: break
            }
        }
        if running == nil { runNext() }
    }

    func stopIfStuck() {
        guard let run = running, run.isRunning, let started = runStarted,
            Date().timeIntervalSince(started) > Self.maxRunSeconds
        else { return }
        log.write("IA: lote \(runningBatch ?? "?") lleva más de 1 hora, se detiene")
        run.stop()
    }

    func recoverInterrupted() {
        let since = Date().addingTimeInterval(-24 * 3600)
        for var batch in stores.batches.load() where batch.status == .running {
            if !batch.items.isEmpty && batch.created > since && batch.mode.hasItems {
                batch.status = .pending
                stores.batches.upsert(batch)
                let title = String(
                    localized: "Quedaron sin terminar estas \(Self.noun(for: batch.mode)) (la Mac se durmió o se cerró la app)")
                let footer = String(localized: "Responde \"si\" para reintentar, \"si 1 3\" para elegir o \"no\" para descartar.")
                notifier.announce(batch, title: title, footer: footer)
            } else {
                batch.status = .interrupted
                stores.batches.upsert(batch)
            }
        }
    }
}
