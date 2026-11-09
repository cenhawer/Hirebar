import AppKit
import HirebarApplication
import HirebarDomain
import HirebarEngine
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

final class StatusMenu: NSObject, NSMenuDelegate {
    let engine: Engine

    init(engine: Engine) {
        self.engine = engine
    }

    var onRefresh: ((Bool) -> Void)?
    var onOpenSettings: ((AgentKind) -> Void)?
    var onOpenChannel: (() -> Void)?
    private var headers: [(NSMenuItem, AgentKind)] = []
    private var checks: [(NSMenuItem, () -> Bool)] = []
    private var labels: [(NSMenuItem, () -> String)] = []
    private var actions: [() -> Void] = []
    private let telegramHeader = NSMenuItem(title: "Telegram", action: nil, keyEquivalent: "")
    private let telegramState = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let claudeItem = NSMenuItem(title: "Claude: en espera", action: nil, keyEquivalent: "")
    private var ticker: Timer?

    static let sourceTitles = [
        "workana": "Workana", "freelancer": "Freelancer",
        "linkedin": "LinkedIn", "getonboard": "Get on Board", "computrabajo": "Computrabajo",
        "elempleo": "elempleo", "magneto": "Magneto",
    ]

    func install(in menu: NSMenu) {
        for kind in AgentKind.allCases {
            let header = NSMenuItem(title: kind.rawValue, action: nil, keyEquivalent: "")
            header.submenu = agentMenu(kind)
            headers.append((header, kind))
            menu.addItem(header)
        }

        menu.addItem(.separator())
        let telegram = NSMenu()
        telegramState.isEnabled = false
        telegram.addItem(telegramState)
        telegram.addItem(.separator())
        telegram.addItem(action("Telegram y avisos…") { [weak self] in self?.onOpenChannel?() })
        telegram.addItem(action("Enviar aviso de prueba") { [weak self] in self?.sendTest() })
        telegramHeader.submenu = telegram
        menu.addItem(telegramHeader)

        claudeItem.isEnabled = false
        menu.addItem(claudeItem)
        menu.addItem(action("Abrir informes") { Self.open(Paths.reports) })
        menu.addItem(action("Ver registro") { LogExport.openRecent() })
        menu.addItem(action("Abrir carpeta de datos") { Self.open(Paths.root) })
        menu.delegate = self

        engine.freelanceRadar.onStatusChange = { [weak self] _ in self?.refresh() }
        engine.jobRadar.onStatusChange = { [weak self] _ in self?.refresh() }
        engine.controller.onStatusChange = { [weak self] _ in self?.refresh() }
        let timer = Timer(timeInterval: 20, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        refresh()
    }

    private func agentMenu(_ kind: AgentKind) -> NSMenu {
        let menu = NSMenu()
        let purpose = NSMenuItem(title: AgentStore.load(kind).purpose, action: nil, keyEquivalent: "")
        purpose.isEnabled = false
        menu.addItem(purpose)
        menu.addItem(.separator())
        menu.addItem(check("Prendido", { AgentStore.load(kind).enabled }) {
            AgentStore.update(kind) { $0.enabled.toggle() }
        })
        if [.jobs, .freelance, .clients].contains(kind) {
            let agents = engine.controller.stores.agents
            let autoSend = check("Envío automático", { AgentStore.load(kind).autoApprove }, { AutoSendConfirmation.toggle(kind, agents: agents) })
            menu.addItem(autoSend)
        }
        let practice = check("Modo práctica", { AgentStore.load(kind).practice }, { [weak self] in self?.togglePractice(kind) })
        menu.addItem(practice)
        let sources = kind == .jobs ? Config.jobSources : kind == .freelance ? Config.freelanceSources : []
        if !sources.isEmpty {
            menu.addItem(.separator())
            for source in sources {
                menu.addItem(check(Self.sourceTitles[source] ?? source, { Config.load().isEnabled(source) }) {
                    var config = Config.load()
                    config.setEnabled(source, !config.isEnabled(source))
                    config.save()
                })
            }
        }
        if kind == .freelance {
            menu.addItem(.separator())
            menu.addItem(label { "Workana: \(Quotas.describe("workana"))" })
            menu.addItem(label { "Freelancer: \(Quotas.describe("freelancer"))" })
        }
        let tasks = AgentStore.load(kind).tasks
        if !tasks.isEmpty {
            menu.addItem(.separator())
            for task in tasks {
                menu.addItem(label { "\(task.mode.title): \(task.scheduleText)" })
            }
        }
        menu.addItem(.separator())
        let runTitle = kind == .profile ? "Regenerar hojas de vida" : "Correr ahora"
        menu.addItem(action(runTitle) { [weak self] in self?.engine.controller.runAgentNow(kind) })
        menu.addItem(action("Ajustes…") { [weak self] in self?.onOpenSettings?(kind) })
        return menu
    }

    static let menuOrigin = "el menú"

    func togglePractice(_ kind: AgentKind) {
        Practice.set(kind, on: !AgentStore.load(kind).practice, from: Self.menuOrigin, agents: engine.controller.stores.agents)
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    func refresh() {
        for (item, kind) in headers { item.title = headerTitle(kind) }
        for (item, isOn) in checks { item.state = isOn() ? .on : .off }
        for (item, text) in labels { item.title = text() }
        claudeItem.title = "\(engine.controller.ai.capitalizedName): \(engine.controller.status)"
        let state = ChannelStatusText.describe(engine.controller.channel.state)
        telegramState.title = state
        telegramHeader.title = state
        onRefresh?(!engine.controller.isIdle)
    }

    private func headerTitle(_ kind: AgentKind) -> String {
        let agent = AgentStore.load(kind)
        guard agent.enabled else { return "\(agent.name): apagado" }
        var title = agent.name
        switch kind {
        case .jobs: title += ": \(engine.jobRadar.status)"
        case .freelance: title += ": \(engine.freelanceRadar.status)"
        default: break
        }
        if let next = engine.scheduler.nextRun(of: kind) { title += " · próxima \(TextTools.countdown(next))" }
        return title
    }

    private func register(_ item: NSMenuItem, _ handler: @escaping () -> Void) -> NSMenuItem {
        item.target = self
        item.tag = actions.count
        actions.append(handler)
        return item
    }

    private func action(_ title: String, _ handler: @escaping () -> Void) -> NSMenuItem {
        register(NSMenuItem(title: title, action: #selector(runMenuAction(_:)), keyEquivalent: ""), handler)
    }

    private func check(_ title: String, _ isOn: @escaping () -> Bool, _ toggle: @escaping () -> Void) -> NSMenuItem {
        let item = action(title) { [weak self] in
            toggle()
            self?.refresh()
        }
        checks.append((item, isOn))
        return item
    }

    private func label(_ text: @escaping () -> String) -> NSMenuItem {
        let item = NSMenuItem(title: text(), action: nil, keyEquivalent: "")
        item.isEnabled = false
        labels.append((item, text))
        return item
    }

    @objc private func runMenuAction(_ sender: NSMenuItem) {
        guard sender.tag >= 0 && sender.tag < actions.count else { return }
        actions[sender.tag]()
    }

    private static func open(_ url: URL) {
        Paths.ensure()
        NSWorkspace.shared.open(url)
    }

    func sendTest() {
        guard engine.controller.notifier.canUseTelegram else {
            onOpenChannel?()
            return
        }
        engine.controller.sendTestMessage()
    }

    static func info(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Hirebar"
        alert.informativeText = message
        alert.runModal()
    }
}
