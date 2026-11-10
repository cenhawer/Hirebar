import AppKit
import HirebarAI
import HirebarApplication
import HirebarDomain
import SwiftUI

extension SetupFacts {
    static func current(engine: Engine, permissions: SystemPermissions) async -> SetupFacts {
        let stores = engine.controller.stores
        return SetupFacts(
            config: stores.config.load(), agents: stores.agents.all(), accounts: stores.contentAccounts.load(),
            channel: engine.controller.channel.state, voiceRecognition: await permissions.state(of: .voiceRecognition),
            notifications: await permissions.state(of: .notifications))
    }
}

@Observable
final class SetupAssistantModel {
    enum Page: Int, CaseIterable {
        case welcome, engine, channel, agents, permissions, done
    }

    let engine: Engine
    let permissions: SystemPermissions
    var page = Page.welcome
    var ownerName = ""
    var engineKind = AIEngineKind.claude
    var checkingEngine = false
    var engineResult: String?
    var engineOK = false
    var agents: [AgentSettings] = []
    var voice = PermissionState.undecided
    var notifications = PermissionState.undecided
    var pending: [SetupStep] = []
    var onFinished: (() -> Void)?

    init(engine: Engine, permissions: SystemPermissions) {
        self.engine = engine
        self.permissions = permissions
    }

    var stores: Repositories { engine.controller.stores }

    func reload() {
        let config = stores.config.load()
        ownerName = config.ownerName == Config.placeholderOwnerName ? "" : config.ownerName
        engineKind = config.aiEngine.kind
        engineOK = config.verifiedEngine == config.aiEngine.kind
        agents = stores.agents.all()
        refreshChecklist()
    }

    func refreshChecklist() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            voice = await permissions.state(of: .voiceRecognition)
            notifications = await permissions.state(of: .notifications)
            pending = SetupChecklist.pending(await SetupFacts.current(engine: engine, permissions: permissions))
        }
    }

    func saveOwner() {
        let name = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var config = stores.config.load()
        config.ownerName = name
        stores.config.save(config)
    }

    func chooseEngine(_ kind: AIEngineKind) {
        engineKind = kind
        var config = stores.config.load()
        config.aiEngine.kind = kind
        stores.config.save(config)
        engineOK = config.verifiedEngine == kind
        engineResult = nil
    }

    func checkEngine() {
        guard !checkingEngine else { return }
        checkingEngine = true
        engineResult = String(localized: "Probando… puede tardar hasta un minuto.")
        let settings = stores.config.load().aiEngine
        EngineCheck.run(settings) { [weak self] ok, text in
            guard let self else { return }
            checkingEngine = false
            engineOK = ok
            engineResult = text
            if ok { Self.markVerified(settings.kind, stores: stores) }
            refreshChecklist()
        }
    }

    static func markVerified(_ kind: AIEngineKind, stores: Repositories) {
        var config = stores.config.load()
        config.verifiedEngine = kind
        stores.config.save(config)
    }

    func setAgent(_ kind: AgentKind, enabled: Bool) {
        stores.agents.update(kind) { $0.enabled = enabled }
        agents = stores.agents.all()
    }

    func request(_ permission: SystemPermission) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await permissions.request(permission)
            refreshChecklist()
        }
    }

    func next() {
        if page == .welcome { saveOwner() }
        page = Page(rawValue: page.rawValue + 1) ?? .done
        refreshChecklist()
    }

    func back() {
        page = Page(rawValue: page.rawValue - 1) ?? .welcome
    }

    func finish() {
        var config = stores.config.load()
        config.setupDismissed = true
        stores.config.save(config)
        onFinished?()
    }
}

final class SetupWindowController {
    let model: SetupAssistantModel
    let channel: ChannelSettingsModel
    private var window: NSWindow?

    init(engine: Engine, channel: ChannelSettingsModel, permissions: SystemPermissions) {
        model = SetupAssistantModel(engine: engine, permissions: permissions)
        self.channel = channel
    }

    func close() {
        window?.close()
    }

    func show() {
        model.reload()
        channel.reload()
        if window == nil {
            let controller = NSHostingController(rootView: SetupAssistantView(model: model, channel: channel))
            let window = NSWindow(contentViewController: controller)
            window.title = String(localized: "Configurar Hirebar")
            window.setContentSize(NSSize(width: 620, height: 560))
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
