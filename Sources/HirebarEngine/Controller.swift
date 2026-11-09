import Foundation
import HirebarAI
import HirebarApplication
import HirebarDomain
import HirebarMedia
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

private let log = Log(.ai)

public final class Controller {
    let targetRules = TargetRulesFile.bundled()
    lazy var executionGuard = ExecutionGuard(
        store: ExecutionApprovals.store, alerts: TelegramExecutionAlerts(notifier: notifier, agents: stores.agents), rules: targetRules)
    var unsavedPauses: [AgentID: AgentPause] = [:]
    public let telegram: Telegram
    public let notifier: Notifier
    public internal(set) var channel: ChannelSetup
    weak var scheduler: Scheduler?
    weak var jobRadar: JobRadar?
    weak var freelanceRadar: FreelanceRadar?

    let clock: Clock
    let aiRunner: AIRunner
    public let stores: Repositories

    public init(telegram: Telegram, stores: Repositories, clock: Clock, aiRunner: AIRunner) {
        self.clock = clock
        self.aiRunner = aiRunner
        self.telegram = telegram
        self.stores = stores
        notifier = Notifier(telegram: telegram, config: stores.config, batches: stores.batches)
        channel = ChannelSetup(settings: try? ChannelSettings.bundled(), telegram: .live(telegram), configs: stores.config, clock: clock)
    }

    public var ai: AI { AI(settings: stores.config.load().aiEngine) }
    var prompts: AgentPrompts { AgentPrompts(stores: stores, ai: ai) }
    var commandParser = (try? CommandVocabularyFile.bundled()).map(CommandParser.init)
    static let noNewsMarker = "SIN_NOVEDADES"
    static let maxRunSeconds: TimeInterval = 3600
    static let authAlertEvery: TimeInterval = 3600

    public var onStatusChange: ((String) -> Void)?
    public private(set) var status = "en espera"
    var queue: [(Batch, [BatchItem])] = []
    private var running: AIRun?
    private var runningBatch: String?
    private var runningMode: Mode?
    private var runningAccount: String?
    private var runStarted: Date?
    private var watchdog: ScheduledWork?
    private var lastAuthAlert: Date?

    static let watchdogInterval: TimeInterval = 60
    static let recoveryDelay: TimeInterval = 5

    public var isIdle: Bool { running == nil && queue.isEmpty }
    public var runningAgent: AgentKind? { runningMode.map(AgentKind.owner) }

    public func start() {
        if watchdog == nil {
            watchdog = clock.every(Self.watchdogInterval, tolerance: 0) { [weak self] in self?.stopIfStuck() }
        }
        Paths.ensure()
        telegram.onMessage = { [weak self] message in self?.handle(message) }
        telegram.onTokenStateChange = { [weak self] in self?.channel.tokenStateChanged() }
        telegram.start()
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
        telegram.send(text, chatId: stores.config.load().chatId, buttons: buttons)
    }

    public func autoApprove(_ batch: Batch) {
        approve(batch, picks: [], approvedBy: .autoSend)
    }

    func approve(_ found: Batch?, picks: [Int], approvedBy: Approver = .person) {
        guard var batch = found else {
            reply("No tengo listas pendientes de las últimas 24 horas.")
            return
        }
        guard batch.status == .pending else {
            reply("Esa lista ya está \(batch.status.rawValue).")
            return
        }
        let chosen = picks.isEmpty ? batch.items
            : picks.filter { $0 >= 1 && $0 <= batch.items.count }.map { batch.items[$0 - 1] }
        guard !chosen.isEmpty else {
            reply("Esos números no están en la lista (van del 1 al \(batch.items.count)).")
            return
        }
        guard let ready = approvedWithinQuota(chosen, from: batch, approvedBy: approvedBy) else { return }
        batch.status = .running
        batch.items = ready
        stores.batches.upsert(batch)
        stores.metrics.bump(batch.mode, "aprobados", ready.count)
        if let id = batch.messageId { telegram.removeButtons(chatId: stores.config.load().chatId, messageId: id) }
        queue.append((batch, ready))
        if running == nil {
            runNext()
        } else {
            reply("Anotado: \(ai.capitalizedName) está terminando otra lista y sigue con esta.")
        }
    }

    public func runScheduled(_ mode: Mode, manual: Bool = false, account: String? = nil) {
        if mode == .linkedInDraft && account == nil {
            // Una publicación por cuenta prendida; las programadas, solo en los días de cada cuenta.
            let today = Date()
            let accounts = stores.contentAccounts.enabled().filter { manual || $0.runs(on: today) }
            if accounts.isEmpty && manual {
                reply("No tienes cuentas de contenido prendidas. Agrégalas en Ajustes → Cuentas de contenido.")
            }
            for item in accounts { runScheduled(mode, manual: manual, account: item.id) }
            return
        }
        if Scheduler.isIdlePortalScan(mode, portals: stores.portals) {
            let agentName = stores.agents.load(AgentKind.owner(of: mode)).name
            if manual { reply("No tienes portales propios activos. Agrégalos en Ajustes → \(agentName).") }
            return
        }
        if (runningMode == mode && runningAccount == account)
            || queue.contains(where: { $0.0.mode == mode && $0.0.account == account }) {
            if manual { reply("Eso ya está en curso.") }
            return
        }
        let batch = Batch(mode: mode, status: .running, manual: manual, account: account)
        if TaskProfiles.profile(for: mode, account: stores.contentAccounts.find(account)).canAct {
            guard prepareScheduledExecution(batch, manual: manual) else { return }
        }
        stores.batches.upsert(batch)
        // Una publicación pedida a mano no espera detrás de las búsquedas: va de primera en la fila.
        if manual && mode == .linkedInDraft {
            let ahead = queue.prefix { $0.0.mode == .linkedInDraft && $0.0.isManual }.count
            queue.insert((batch, []), at: ahead)
        } else {
            queue.append((batch, []))
        }
        let accountTitle = stores.contentAccounts.find(account)?.title ?? "tu cuenta"
        if manual {
            switch mode {
            case .weeklyReport: reply("Preparando el informe semanal; te lo mando al terminar.")
            case .linkedInDraft:
                reply("Armando la publicación para \(accountTitle) con sus imágenes; te la mando antes de publicar nada."
                      + (running == nil ? "" : " Empieza apenas termine lo que está corriendo ahora."))
            case .linkedInPublish: reply("Publicando en \(accountTitle) la publicación que aprobaste; te confirmo al terminar.")
            case .followUp: reply("Revisando seguimientos ahora; te aviso si escribo a algún cliente.")
            case .prospectingSend: reply("Enviando los correos aprobados; te confirmo al terminar.")
            case .social: reply("Buscando vacantes publicadas en redes; te aviso si encuentro algo.")
            case .prospecting: reply("Buscando empresas y negocios para escribirles; te mando la lista al terminar.")
            case .profileUpdate: reply("Actualizando tu perfil y tus hojas de vida; te mando los PDF al terminar.")
            default: break
            }
        }
        if running == nil { runNext() }
    }

    private func stopIfStuck() {
        guard let run = running, run.isRunning, let started = runStarted,
              Date().timeIntervalSince(started) > Self.maxRunSeconds else { return }
        log.write("IA: lote \(runningBatch ?? "?") lleva más de 1 hora, se detiene")
        run.stop()
    }

    private func recoverInterrupted() {
        let since = Date().addingTimeInterval(-24 * 3600)
        for var batch in stores.batches.load() where batch.status == .running {
            if !batch.items.isEmpty && batch.created > since && batch.mode.hasItems {
                batch.status = .pending
                stores.batches.upsert(batch)
                let title = "Quedaron sin terminar estas \(Self.noun(for: batch.mode)) (la Mac se durmió o se cerró la app)"
                let footer = "Responde \"si\" para reintentar, \"si 1 3\" para elegir o \"no\" para descartar."
                notifier.announce(batch, title: title, footer: footer)
            } else {
                batch.status = .interrupted
                stores.batches.upsert(batch)
            }
        }
    }

    static func noun(for mode: Mode) -> String {
        mode == .jobs ? "postulaciones" : mode == .followUpSend ? "seguimientos" : "propuestas"
    }

    private func runNext() {
        guard running == nil, !queue.isEmpty else { return }
        let (pending, items) = queue.removeFirst()
        var batch = pending
        let owner = stores.config.load().ownerName
        if batch.mode == .linkedInDraft, let account = stores.contentAccounts.find(batch.account) {
            SlideRenderer.prepare(account)
        }
        let account = stores.contentAccounts.find(batch.account)
        let profile = TaskProfiles.profile(for: batch.mode, account: account)
        if profile.canAct, let pause = activePause(of: ExecutionApprovals.agent(of: batch.mode)) {
            batch.status = batch.mode.hasItems ? .pending : .interrupted
            stores.batches.upsert(batch)
            releaseApproval(of: batch.id)
            reply(pausedNotice(batch.mode, pause))
            runNext()
            return
        }
        if profile.canAct && simulateIfPracticing(batch) {
            runNext()
            return
        }
        if profile.canAct {
            do {
                try executionGuard.prepareRun(batch: batch.id)
            } catch {
                batch.status = .failed
                stores.batches.upsert(batch)
                releaseApproval(of: batch.id)
                reply("No pude limpiar el registro anterior de la lista \(batch.id), así que no la ejecuto: \(error.localizedDescription)")
                runNext()
                return
            }
        }
        let batchId = batch.id
        let mode = batch.mode
        let request = AIRunRequest(
            runId: batchId,
            engine: ai.settings,
            prompt: prompts.prompt(for: batch, items: items, owner: owner),
            playbook: Paths.playbook(for: batch.mode),
            profile: profile,
            browser: TaskProfiles.needsBrowser(batch.mode, account: account)
        )
        let started = aiRunner.start(request) { [weak self] result in
            self?.finished(batchId, mode: mode, items: items, result: result)
        }
        let run: AIRun
        switch started {
        case .success(let launched):
            run = launched
        case .failure(let failure):
            switch failure {
            case .unavailable(let message, let status):
                reply(message)
                setStatus(status)
            case .couldNotOpen(let detail):
                reply("No pude abrir \(ai.name): \(detail)")
            }
            batch.status = .failed
            stores.batches.upsert(batch)
            if profile.canAct { releaseApproval(of: batch.id) }
            runNext()
            return
        }
        running = run
        runningBatch = batchId
        runningMode = mode
        runningAccount = batch.account
        runStarted = Date()
        setStatus(AgentPrompts.statusText(for: mode, count: items.count, since: TextTools.shortTime()))
        if mode == .freelance || mode == .jobs {
            reply("\(ai.capitalizedName) empezó: \(items.count) \(Self.noun(for: mode)). Te aviso cuando termine (suele tardar 5–20 min).")
        }
        Log(agent: AgentKind.owner(of: mode)).write("IA: inicia lote \(batchId) con \(items.count) elemento(s), perfil \(profile.phase)")
        clock.after(Self.maxRunSeconds) { [weak self] in
            guard let self, self.runningBatch == batchId, let run = self.running, run.isRunning else { return }
            log.write("IA: lote \(batchId) superó 1 hora, se detiene")
            run.stop()
        }
    }

    private func finished(_ batchId: String, mode: Mode, items: [BatchItem], result: AIRunResult) {
        running = nil
        runningBatch = nil
        runningMode = nil
        runningAccount = nil
        let code = result.code
        let output = result.output
        Log(agent: AgentKind.owner(of: mode)).write("IA: lote \(batchId) terminó con código \(code)")

        let acts = TaskProfiles.profile(for: mode, account: nil).canAct
        if acts { reportRestoredFiles(result.restoredFiles, after: batchId) }
        if result.authFailed {
            handleAuthFailure(batchId, mode: mode, items: acts ? settleInterruptedExecution(batchId, mode: mode, items: items) : items)
        } else {
            if var batch = stores.batches.find(id: batchId) {
                batch.status = code == 0 ? .done : .failed
                batch.result = String(output.suffix(2000))
                stores.batches.upsert(batch)
            }
            report(batchId, mode: mode, code: code, output: output)
            if acts { verify(batchId, mode: mode) }
        }
        setStatus(queue.isEmpty ? "en espera" : "siguiente lista…")
        runNext()
    }

    @discardableResult
    func verify(_ batchId: String, mode: Mode) -> ExecutionVerification? {
        let agent = ExecutionApprovals.agent(of: mode)
        do {
            return try executionGuard.verify(batch: batchId, agent: agent)
        } catch ExecutionGuardFailure.pauseNotSaved(let pause, let verification) {
            unsavedPauses[agent] = pause
            log.write("Verificación: no pude guardar la pausa de \(agent.rawValue); queda en pausa mientras la app siga abierta")
            return verification
        } catch ExecutionGuardFailure.verificationNotSaved(let verification) {
            log.write("Verificación: no pude guardar la verificación de \(batchId); su cupo queda reservado")
            return verification
        } catch {
            log.write("Verificación: \(batchId) falló: \(error.localizedDescription)")
            return nil
        }
    }

    private func reportRestoredFiles(_ restored: [String], after batchId: String) {
        guard !restored.isEmpty else { return }
        log.write("Ejecución \(batchId): restauré archivos protegidos que cambió la IA (\(restored.joined(separator: ", ")))")
        reply("\(ai.capitalizedName) cambió archivos que no debía tocar (\(restored.joined(separator: ", "))); los dejé como estaban.")
    }

    static let practiceSummaryLimit = 15

    func simulateIfPracticing(_ batch: Batch) -> Bool {
        let kind = AgentKind.owner(of: batch.mode)
        let agent = stores.agents.load(kind)
        guard agent.practice else { return false }
        let items = executionGuard.approvedItems(batch: batch.id).map(\.proposal)
        do {
            try PracticeLog(batch: batch.id, agent: kind.rawValue, at: Date(), wouldSend: items).save()
        } catch {
            log.write("Práctica: no pude guardar lo que habría enviado \(batch.id): \(error.localizedDescription)")
        }
        releaseApproval(of: batch.id)
        var finished = batch
        finished.status = .done
        finished.result = Self.practiceResult
        stores.batches.upsert(finished)
        stores.metrics.bump(batch.mode, Self.practiceMetric, items.count)
        Log(agent: kind).write("Práctica: \(kind.rawValue) simuló \(items.count) acción(es) del lote \(batch.id)")
        reply(Self.practiceSummary(agentName: agent.name, items: items))
        return true
    }

    static let practiceResult = "práctica"
    static let practiceMetric = "practica"

    static func practiceSummary(agentName: String, items: [Proposal]) -> String {
        let lines = items.prefix(practiceSummaryLimit).map { "• \($0.action.rawValue) · \($0.title) · \($0.target.displayText)" }
        let more = items.count > practiceSummaryLimit ? ["… y \(items.count - practiceSummaryLimit) más."] : []
        return (["Modo práctica: \(agentName) no envió nada. Habría hecho \(items.count):"] + lines + more)
            .joined(separator: "\n")
    }

    func activePause(of agent: AgentID) -> AgentPause? {
        executionGuard.pause(of: agent) ?? unsavedPauses[agent]
    }

    func releaseApproval(of batchId: String) {
        do {
            try executionGuard.release(batch: batchId)
        } catch {
            log.write("Verificación: no pude liberar lo aprobado de \(batchId); su cupo queda reservado hoy")
        }
    }

    func settleInterruptedExecution(_ batchId: String, mode: Mode, items: [BatchItem]) -> [BatchItem] {
        guard executionGuard.hasActionLog(batch: batchId) else {
            releaseApproval(of: batchId)
            return items
        }
        guard let verification = verify(batchId, mode: mode) else { return items }
        let done = Set(verification.verdicts.filter { $0.record?.outcome == .done }.map(\.itemId))
        return items.filter { !done.contains($0.id) }
    }

    private func handleAuthFailure(_ batchId: String, mode: Mode, items: [BatchItem]) {
        if var batch = stores.batches.find(id: batchId) {
            let retry = mode.hasItems && !items.isEmpty
            batch.status = retry ? .pending : mode.hasItems ? .done : .interrupted
            if mode.hasItems { batch.items = items }
            stores.batches.upsert(batch)
        }
        log.write("IA: la sesión venció; lote \(batchId) queda para reintentar")
        let now = Date()
        if lastAuthAlert.map({ now.timeIntervalSince($0) > Self.authAlertEvery }) ?? true {
            lastAuthAlert = now
            let expired = "La sesión de \(ai.settings.kind.title) se venció y no pude trabajar. \(ClaudeCLI.loginHint(ai.settings.kind))"
            reply(expired + " Las listas de propuestas y postulaciones quedaron guardadas: responde \"si\" para reintentar la última.")
        }
    }

    private func report(_ batchId: String, mode: Mode, code: Int32, output: String) {
        if code == 0 && TaskProfiles.executionMode(for: mode) != nil {
            offerProposals(from: output, mode: mode)
            if output.contains(Self.noNewsMarker) { return }
        }
        if code == 0 && (mode == .followUp || mode == .social || mode == .portalScanJobs || mode == .portalScanFreelance)
            && output.contains(Self.noNewsMarker) {
            Log(agent: AgentKind.owner(of: mode)).write("\(mode.rawValue): sin novedades")
            if batchId.hasPrefix("gm-") {
                let summary = output.replacingOccurrences(of: Self.noNewsMarker, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                reply("Seguimientos: hoy no tocaba escribirle a nadie.\n\n" + (summary.isEmpty ? "Sin más detalle." : String(summary.suffix(3500))))
            }
            return
        }
        guard code == 0 && !output.isEmpty else {
            let detail = output.isEmpty ? "sin salida" : String(output.suffix(1500))
            let failure = "\(ai.capitalizedName) terminó con error (código \(code)). Detalle: \(detail)"
            reply(failure + "\nRegistro: workspace/ejecuciones/\(batchId).log")
            return
        }
        reply(String(ProposalParser.removingBlock(from: output).suffix(3800)))
        switch mode {
        case .prospecting: offerProspectingEmails()
        case .profileUpdate: finishProfileUpdate()
        case .linkedInDraft:
            sendSlides(stores.batches.find(id: batchId)?.account)
        default: break
        }
    }

    private func sendSlides(_ accountId: String?) {
        guard let account = stores.contentAccounts.find(accountId) else {
            reply("No encontré la cuenta de esta publicación en Ajustes → Cuentas de contenido.")
            return
        }
        let several = stores.contentAccounts.load().count > 1
        let publish = several ? "publica \(account.id)" : "publica"
        let change = several ? "post \(account.id) cambia <qué>" : "post cambia <qué>"
        let skip = several ? "post \(account.id) salta" : "post salta"
        let ask = "¿Lo subo a \(account.title)? Responde \"\(publish)\" para subirlo tal cual, \"\(change)\" para ajustarlo o \"\(skip)\" para no publicarlo."
        SlideRenderer.renderAll(account) { [weak self] made, failed in
            var notes: [String] = []
            if made.isEmpty {
                let aiName = self?.ai.name ?? "la IA"
                notes.append("Esta vez no salieron imágenes (\(aiName) no dejó las láminas o Chrome no pudo convertirlas).")
            } else if failed > 0 {
                notes.append("\(failed) lámina(s) no se pudieron convertir.")
            }
            self?.notifier.sendPhotos(made, caption: "\(account.title): imágenes de la publicación (\(made.count))") {
                if let text = self?.stores.contentAccounts.draftText(account) {
                    self?.reply("Texto de la publicación de \(account.title), listo para copiar:\n\n\(text)")
                }
                guard account.video else {
                    self?.reply((notes + [ask]).joined(separator: " "))
                    return
                }
                ReelRenderer.renderPreview(account) { video, problem in
                    let rest = {
                        if let script = ReelRenderer.readingScript(account) {
                            self?.stores.runState.setWaitingVoiceAccount(account.id)
                            self?.reply(script)
                        }
                        if let text = self?.stores.contentAccounts.videoDescription(account) {
                            self?.reply("Descripción del video de \(account.title), lista para copiar:\n\n\(text)")
                        }
                        self?.reply((notes + [ask + " El video se sube cuando me mandes tu voz."]).joined(separator: " "))
                    }
                    guard let video else {
                        notes.append("No salió la vista previa del video: \(problem ?? "sin detalle").")
                        rest()
                        return
                    }
                    self?.notifier.sendVideo(video, caption: "\(account.title): vista previa del video, sin voz") { rest() }
                }
            }
        }
    }

    /// Cuenta cuyo video está esperando la nota de voz de la persona.

    /// Texto de un archivo para mandarlo a Telegram tal cual, listo para copiar y pegar.
    static let proposalSeenWindow: TimeInterval = 30 * 86400

    private func offerProposals(from output: String, mode: Mode) {
        guard let execution = TaskProfiles.executionMode(for: mode) else { return }
        let proposals: [Proposal]
        switch ProposalParser.parse(output, rules: targetRules) {
        case .success(let parsed):
            proposals = parsed
        case .failure(.blockMissing):
            return
        case .failure(let failure):
            Log(agent: AgentKind.owner(of: mode)).write("\(mode.rawValue): la lista de propuestas no es válida (\(failure))")
            reply("\(ai.capitalizedName) no dejó la lista en el formato esperado; no la muestro. El detalle quedó en el registro.")
            return
        }
        let intake = ProposalIntake(window: Self.proposalSeenWindow, rules: targetRules).accept(
            proposals,
            allowed: TaskProfiles.allowedProposals(for: mode),
            seen: ExecutionApprovals.store.seenProposals(),
            now: Date()
        )
        for proposal in intake.rejected {
            log.write("\(mode.rawValue): descartada una propuesta con acción no permitida para esta tarea (\(proposal.action.rawValue))")
        }
        let fresh = intake.fresh
        guard !fresh.isEmpty else { return }
        let batch = Batch(mode: execution, items: fresh.map { BatchItem($0) }, status: .pending)
        guard offer(batch, proposals: fresh, title: Self.proposalsTitle(for: mode, count: fresh.count)) else { return }
        do {
            try ExecutionApprovals.store.saveSeenProposals(intake.seen)
        } catch {
            log.write("\(mode.rawValue): no pude guardar qué propuestas ya mostré: \(error.localizedDescription)")
        }
    }

    @discardableResult
    private func offer(_ batch: Batch, proposals: [Proposal], title: String) -> Bool {
        do {
            try ExecutionApprovals.store.saveProposals(proposals, batch: batch.id)
        } catch {
            log.write("\(batch.mode.rawValue): no pude guardar la copia de las propuestas: \(error.localizedDescription)")
            reply("No pude guardar la lista para aprobar, así que no te la muestro: \(error.localizedDescription)")
            return false
        }
        stores.batches.upsert(batch)
        stores.metrics.bump(batch.mode, "avisados", proposals.count)
        let auto = stores.agents.load(AgentKind.owner(of: batch.mode)).autoApprove
        let footer =
            auto
            ? "\(ai.capitalizedName) ya los está procesando; te aviso al terminar."
            : "Responde \"si\" para que \(ai.name) los procese, \"si 1 3\" para elegir o \"no\" para descartar."
        notifier.announce(batch, title: title + (auto ? " (envío automático)" : ""), footer: footer)
        if auto { autoApprove(batch) }
        return true
    }

    private func finishProfileUpdate() {
        stores.profile.clearChangeRequests()
        let profile = stores.profile.load()
        guard !profile.cvVariants.isEmpty else {
            reply("perfil.json no tiene hojas de vida definidas (cvVariants), así que no generé PDF.")
            return
        }
        CVRenderer.renderAll(profile) { [weak self] result in
            for file in result.made {
                self?.notifier.sendFile(file, caption: "Hoja de vida actualizada: \(file.lastPathComponent)")
            }
            var lines = ["Hojas de vida: \(result.made.count) de \(profile.cvVariants.count) listas."]
            let aiName = self?.ai.capitalizedName ?? "La IA"
            if !result.missing.isEmpty { lines.append("\(aiName) no dejó el HTML de: \(result.missing.joined(separator: ", ")).") }
            if !result.failed.isEmpty { lines.append("No pude crear el PDF de: \(result.failed.joined(separator: ", ")) (revisa que Google Chrome esté instalado).") }
            self?.reply(lines.joined(separator: "\n"))
        }
    }

    private func offerProspectingEmails() {
        switch ExecutionApprovals.emailDrafts(rules: targetRules, pending: stores.prospecting.pendingEmails()) {
        case .none:
            return
        case .invalid(let ids):
            let numbers = ids.joined(separator: ", ")
            Log(agent: .clients).write("Prospección: correos incompletos o repetidos en pendientes.json (\(numbers))")
            reply("\(ai.capitalizedName) dejó correos sin destinatario, asunto o texto válidos (\(numbers)); no te muestro la lista.")
        case .found(let drafts):
            let batch = Batch(mode: .prospectingSend, items: drafts.map { BatchItem($0.proposal, kind: $0.kind) }, status: .pending)
            offer(batch, proposals: drafts.map(\.proposal), title: "Correos de hoy: \(drafts.count) para aprobar")
        }
    }

    static func proposalsTitle(for mode: Mode, count: Int) -> String {
        switch mode {
        case .social: return "Redes: \(count) publicación(es) con vacantes para ti"
        case .followUp: return "Seguimientos: \(count) para aprobar"
        case .portalScanFreelance: return "Tus portales: \(count) proyecto(s) para ti"
        default: return "Tus portales: \(count) vacante(s) para ti"
        }
    }

    func pausedNotice(_ mode: Mode, _ pause: AgentPause) -> String {
        let kind = AgentKind.owner(of: mode)
        let name = stores.agents.load(kind).name
        return "\(name) está en pausa desde la lista \(pause.batch) porque algo no coincidió con lo aprobado. "
            + "No ejecuto nada de \(name) hasta que escribas \"reanudar \(kind.rawValue)\"."
    }

    private func approvedWithinQuota(_ chosen: [BatchItem], from batch: Batch, approvedBy: Approver) -> [BatchItem]? {
        let agentID = ExecutionApprovals.agent(of: batch.mode)
        if let pause = activePause(of: agentID) {
            reply(pausedNotice(batch.mode, pause))
            return nil
        }
        let agentSettings = stores.agents.load(AgentKind.owner(of: batch.mode))
        let plan: ExecutionPlan
        do {
            plan = try executionGuard.approve(
                ExecutionApprovals.proposals(for: batch, items: chosen),
                batch: batch.id,
                approvedBy: approvedBy,
                agent: agentID,
                dailyLimit: agentSettings.dailyLimit
            )
        } catch {
            reply("No pude guardar la copia de lo aprobado, así que no ejecuto la lista: \(error.localizedDescription)")
            return nil
        }
        if !plan.held.isEmpty { holdForPerson(plan.held, from: batch) }
        guard !plan.now.isEmpty else {
            if !plan.held.isEmpty { remove(plan.held.map(\.proposal.id), from: batch.id) }
            if plan.held.isEmpty {
                reply("Hoy ya se cumplió el cupo diario de \(agentSettings.name). La lista sigue pendiente: apruébala mañana.")
            }
            return nil
        }
        let approvedIds = Set(plan.now.map(\.proposal.id))
        let ready = chosen.filter { approvedIds.contains($0.id) }
        let heldIds = Set(plan.held.map(\.proposal.id))
        let deferred = chosen.filter { !approvedIds.contains($0.id) && !heldIds.contains($0.id) }
        if !deferred.isEmpty { deferBeyondQuota(deferred, from: batch, running: ready.count) }
        return ready
    }

    private func holdForPerson(_ held: [ApprovedItem], from batch: Batch) {
        let ids = Set(held.map(\.proposal.id))
        let rest = Batch(mode: batch.mode, items: batch.items.filter { ids.contains($0.id) }, status: .pending)
        do {
            try ExecutionApprovals.store.saveProposals(held.map(\.proposal), batch: rest.id)
        } catch {
            reply("No pude separar los mensajes que necesitan tu revisión; quedan en la lista \(batch.id): \(error.localizedDescription)")
            return
        }
        stores.batches.upsert(rest)
        notifier.announce(
            rest, title: "Estos mensajes no se envían solos",
            footer: "Revisa el texto y responde \"si\" para enviarlos, \"si 1 3\" para elegir o \"no\" para descartar.")
    }

    private func remove(_ ids: [String], from batchId: String) {
        guard var batch = stores.batches.find(id: batchId) else { return }
        let removed = Set(ids)
        batch.items.removeAll { removed.contains($0.id) }
        if batch.items.isEmpty {
            batch.status = .done
            if let id = batch.messageId { telegram.removeButtons(chatId: stores.config.load().chatId, messageId: id) }
        }
        stores.batches.upsert(batch)
    }

    private func deferBeyondQuota(_ items: [BatchItem], from batch: Batch, running count: Int) {
        let rest = Batch(mode: batch.mode, items: items, status: .pending)
        let ids = Set(items.map(\.id))
        let proposals = ExecutionApprovals.store.proposals(batch: batch.id).filter { ids.contains($0.id) }
        do {
            if !proposals.isEmpty { try ExecutionApprovals.store.saveProposals(proposals, batch: rest.id) }
        } catch {
            reply("Hoy queda cupo para \(count). No pude guardar los otros \(items.count) para mañana: vuelve a pedirlos cuando aparezcan.")
            return
        }
        stores.batches.upsert(rest)
        reply("Hoy queda cupo para \(count): ejecuto esos y dejo \(items.count) en una lista pendiente para mañana.")
    }

    private func prepareScheduledExecution(_ batch: Batch, manual: Bool) -> Bool {
        let agentID = ExecutionApprovals.agent(of: batch.mode)
        if let pause = activePause(of: agentID) {
            reply(pausedNotice(batch.mode, pause))
            return false
        }
        guard batch.mode == .linkedInPublish,
            let proposal = stores.contentAccounts.find(batch.account).flatMap(ExecutionApprovals.publishProposal)
        else {
            log.write("\(batch.mode.rawValue): no se ejecuta sin una lista aprobada")
            if manual { reply("Eso solo se ejecuta sobre una lista que hayas aprobado; no ejecuto nada.") }
            return false
        }
        let agentSettings = stores.agents.load(AgentKind.owner(of: batch.mode))
        do {
            let plan = try executionGuard.approve(
                [proposal], batch: batch.id, approvedBy: manual ? .person : .autoSend, agent: agentID, dailyLimit: agentSettings.dailyLimit)
            guard !plan.now.isEmpty else {
                reply(
                    plan.held.isEmpty
                        ? "Hoy ya se cumplió el cupo diario de \(agentSettings.name); no publico nada más hoy."
                        : "Las publicaciones solo salen cuando respondes \"publica\".")
                return false
            }
            return true
        } catch {
            reply("No pude guardar la copia de lo aprobado, así que no ejecuto nada: \(error.localizedDescription)")
            return false
        }
    }
}
