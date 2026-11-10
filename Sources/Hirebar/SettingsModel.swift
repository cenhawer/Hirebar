import AppKit
import HirebarAI
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import SwiftUI

enum SettingsPage: Hashable {
    case agent(AgentKind)
    case skills
    case content
    case engine
    case channel
}

final class SettingsWindowController {
    private let model: SettingsModel
    let channel: ChannelSettingsModel

    init(engine: Engine) {
        model = SettingsModel(agentRepository: engine.controller.stores.agents)
        channel = ChannelSettingsModel(engine: engine)
    }
    private var window: NSWindow?

    var onSaved: (() -> Void)? {
        get { model.onSaved }
        set { model.onSaved = newValue }
    }

    func show(_ page: SettingsPage? = nil) {
        model.reload()
        if let page { model.selection = page }
        if window == nil {
            let controller = NSHostingController(rootView: SettingsView(model: model, channel: channel))
            let window = NSWindow(contentViewController: controller)
            window.title = String(localized: "Ajustes de Hirebar")
            window.setContentSize(NSSize(width: 820, height: 560))
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct EditableSkill: Identifiable {
    let id = UUID()
    var skill: Skill
}

struct EditableAccount: Identifiable {
    let id = UUID()
    var account: ContentAccount
}

struct DayOption: Identifiable {
    let id: String
    let title: String
}

@Observable
final class SettingsModel {
    let agentRepository: AgentRepository

    init(agentRepository: AgentRepository) {
        self.agentRepository = agentRepository
    }

    var agents: [AgentSettings] = []
    var sources: [String: Bool] = [:]
    var skills: [EditableSkill] = []
    var portals: [CustomPortal] = []
    var contentAccounts: [EditableAccount] = []
    var engine = AIEngineSettings()
    var engineCheck: String?
    var engineCheckOK = false
    var checkingEngine = false
    var selection: SettingsPage? = .agent(.jobs)
    var message: String?

    var onSaved: (() -> Void)?

    func reload() {
        agents = AgentStore.all()
        let config = Config.load()
        sources = Dictionary(uniqueKeysWithValues: (Config.jobSources + Config.freelanceSources).map { ($0, config.isEnabled($0)) })
        skills = Profile.load().skills.map { EditableSkill(skill: $0) }
        portals = PortalStore.load()
        contentAccounts = ContentAccountStore.load().map { EditableAccount(account: $0) }
        engine = Config.load().aiEngine
        engineCheck = nil
        message = nil
    }

    func save() {
        let invalid = portals.filter { !$0.isValid }
        guard invalid.isEmpty else {
            message = String(localized: "Revisa los portales: cada uno necesita nombre y un enlace que empiece por https://")
            return
        }
        guard let accounts = validatedAccounts() else { return }
        saveAgents()
        var config = Config.load()
        for (source, on) in sources { config.setEnabled(source, on) }
        config.aiEngine = engine
        config.save()
        let result: String
        do {
            try PortalStore.save(portals)
            try ContentAccountStore.save(accounts)
            try ProfileEditor.saveSkills(skills.map(\.skill))
            result = String(localized: "Guardado. Aplica desde la próxima búsqueda.")
        } catch {
            result = String(localized: "Los agentes se guardaron, pero no pude guardar las habilidades: \(error.localizedDescription)")
        }
        reload()
        message = result
        onSaved?()
    }

    func validatedAccounts() -> [ContentAccount]? {
        var accounts: [ContentAccount] = []
        for (index, item) in contentAccounts.enumerated() {
            var account = item.account
            account.id = ContentAccountStore.slug(account.id)
            if account.id.isEmpty { account.id = ContentAccountStore.slug(account.name) }
            if account.id.isEmpty { account.id = "cuenta-\(index + 1)" }
            guard !accounts.contains(where: { $0.id == account.id }) else {
                message = String(localized: "Dos cuentas de contenido tienen el identificador \"\(account.id)\"; cambia uno.")
                return nil
            }
            let colors = [
                account.palette.background, account.palette.surface, account.palette.accent,
                account.palette.text, account.palette.muted,
            ]
            guard colors.allSatisfy(Color.isHex) else {
                message = String(localized: "Revisa los colores de \(account.title): deben ser como #F07C32.")
                return nil
            }
            accounts.append(account)
        }
        return accounts
    }

    func saveAgents() {
        let turnedOn = AutoSend.newlyEnabled(saved: AgentKind.allCases.map(AgentStore.load), edited: agents)
        let confirmed = turnedOn.isEmpty || AutoSendConfirmation.ask(turnedOn, agents: agentRepository)
        for edited in agents {
            var agent = Self.normalized(edited, portals: portals)
            if !confirmed && turnedOn.contains(agent.id) { agent.autoApprove = false }
            AgentStore.save(agent)
        }
        if confirmed {
            for kind in turnedOn { AutoSend.turnOn(kind, from: AutoSendConfirmation.settingsOrigin, agents: agentRepository) }
        }
    }

    static func normalized(_ edited: AgentSettings, portals: [CustomPortal]) -> AgentSettings {
        var agent = edited
        if !portals.filter({ $0.agent == agent.id && $0.enabled }).isEmpty { agent.ensurePortalScanTask() }
        if agent.name.trimmingCharacters(in: .whitespaces).isEmpty { agent.name = AgentSettings.defaults(for: agent.id).name }
        if let minutes = agent.searchEveryMinutes { agent.searchEveryMinutes = max(15, minutes) }
        if let limit = agent.dailyLimit { agent.dailyLimit = max(0, limit) }
        agent.tasks = agent.tasks.map { task in
            var task = task
            task.hours = Array(Set(task.hours.filter { (0...23).contains($0) })).sorted()
            task.windowHours = max(1, task.windowHours)
            return task
        }
        return agent
    }

    func agentBinding(_ kind: AgentKind) -> Binding<AgentSettings>? {
        guard let current = agents.first(where: { $0.id == kind }) else { return nil }
        return Binding(
            get: { [weak self] in self?.agents.first(where: { $0.id == kind }) ?? current },
            set: { [weak self] value in
                guard let self, let index = self.agents.firstIndex(where: { $0.id == kind }) else { return }
                self.agents[index] = value
            })
    }

    func portalsBinding(_ kind: AgentKind) -> Binding<[CustomPortal]> {
        Binding(
            get: { [weak self] in self?.portals.filter { $0.agent == kind } ?? [] },
            set: { [weak self] value in
                guard let self else { return }
                self.portals = self.portals.filter { $0.agent != kind } + value
            })
    }

    static func markVerified(_ kind: AIEngineKind) {
        var config = Config.load()
        config.verifiedEngine = kind
        config.save()
    }

    func checkEngine() {
        checkingEngine = true
        engineCheck = String(localized: "Probando… puede tardar hasta un minuto.")
        let kind = engine.kind
        EngineCheck.run(engine) { [weak self] ok, text in
            if ok { Self.markVerified(kind) }
            self?.checkingEngine = false
            self?.engineCheckOK = ok
            self?.engineCheck = text
        }
    }

    func addPortal(_ kind: AgentKind) {
        portals.append(CustomPortal(name: "", agent: kind, url: "https://"))
    }

    func sourceBinding(_ source: String) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?.sources[source] ?? true },
            set: { [weak self] value in self?.sources[source] = value })
    }

    func revealFile() {
        Paths.ensure()
        AgentStore.writeMissingDefaults()
        switch selection {
        case .skills:
            NSWorkspace.shared.activateFileViewerSelecting([Profile.url])
        case .engine, .channel:
            NSWorkspace.shared.activateFileViewerSelecting([Paths.config])
        case .content:
            if !FileManager.default.fileExists(atPath: ContentAccountStore.url.path) {
                try? ContentAccountStore.save(ContentAccountStore.load())
            }
            NSWorkspace.shared.activateFileViewerSelecting([ContentAccountStore.url])
        case .agent(let kind):
            NSWorkspace.shared.activateFileViewerSelecting([AgentStore.url(for: kind)])
        case nil:
            NSWorkspace.shared.open(Paths.workspace)
        }
    }
}
