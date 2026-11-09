import AppKit
import HirebarApplication
import HirebarDomain
import HirebarEngine
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import ServiceManagement
import SwiftUI

struct SourceToggle: Identifiable {
    let id: String
    let title: String
    let on: Bool
}

struct AgentCardData: Identifiable {
    let id: AgentKind
    let name: String
    let purpose: String
    let status: String
    let next: String
    let enabled: Bool
    let autoApprove: Bool
    let practice: Bool
    let working: Bool
    let stats: [String]
    let sources: [SourceToggle]
    let schedule: [String]
    let pauseReason: String?

    var canAutoApprove: Bool { [.jobs, .freelance, .clients].contains(id) }
}

enum AgentStyle {
    static func symbol(_ kind: AgentKind) -> String {
        switch kind {
        case .jobs: return "briefcase.fill"
        case .freelance: return "laptopcomputer"
        case .clients: return "building.2.fill"
        case .content: return "megaphone.fill"
        case .profile: return "person.text.rectangle.fill"
        case .analyst: return "chart.bar.fill"
        }
    }

    static func tint(_ kind: AgentKind) -> Color {
        switch kind {
        case .jobs: return .blue
        case .freelance: return .purple
        case .clients: return .orange
        case .content: return .pink
        case .profile: return .teal
        case .analyst: return .green
        }
    }
}

final class PanelModel: ObservableObject {
    let engine: Engine

    init(engine: Engine) {
        self.engine = engine
    }

    @Published var agents: [AgentCardData] = []
    @Published var claude = "en espera"
    @Published var aiName = "Claude"
    @Published var claudeBusy = false
    @Published var telegram = ""
    @Published var telegramReady = false
    @Published var opensAtLogin = false

    var onQuit: (() -> Void)?
    var onOpenSettings: ((SettingsPage?) -> Void)?

    func refresh() {
        let running = engine.controller.runningAgent
        let pauses = engine.controller.pauseReasons()
        agents = AgentKind.allCases.map { card($0, running: running, pauseReason: pauses[$0]) }
        claude = engine.controller.status
        aiName = AI.capitalizedName
        claudeBusy = !engine.controller.isIdle
        let channel = engine.controller.channel.state
        telegram = ChannelStatusText.describe(channel)
        telegramReady = ChannelStatusText.isReady(channel)
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func card(_ kind: AgentKind, running: AgentKind?, pauseReason: String?) -> AgentCardData {
        let agent = AgentStore.load(kind)
        let config = Config.load()
        let working = running == kind
        var status: String
        switch kind {
        case .jobs: status = "Última búsqueda: \(engine.jobRadar.status)"
        case .freelance: status = "Última búsqueda: \(engine.freelanceRadar.status)"
        case .profile: status = "\(Profile.load().cvVariants.count) hojas de vida · escribe \"logro\" o \"hv\" en Telegram"
        case .clients, .content, .analyst: status = agent.tasks.first.map { "Corre \($0.scheduleText)" } ?? "Sin horario"
        }
        if working { status = Self.capitalized(engine.controller.status) }
        let next = nextText(kind, enabled: agent.enabled, working: working, paused: pauseReason != nil)
        var stats = WeeklyStats.lines(for: kind)
        if kind == .freelance {
            stats += ["Workana \(Quotas.describe("workana"))", "Freelancer \(Quotas.describe("freelancer"))"]
        }
        if !stats.isEmpty && [.jobs, .freelance, .clients].contains(kind) { stats[0] = "Esta semana: " + stats[0] }
        let ids = kind == .jobs ? Config.jobSources : kind == .freelance ? Config.freelanceSources : []
        return AgentCardData(
            id: kind,
            name: agent.name,
            purpose: agent.purpose,
            status: status,
            next: next,
            enabled: agent.enabled,
            autoApprove: agent.autoApprove,
            practice: agent.practice,
            working: working,
            stats: stats,
            sources: ids.map { SourceToggle(id: $0, title: StatusMenu.sourceTitles[$0] ?? $0, on: config.isEnabled($0)) },
            schedule: agent.tasks.map { "\($0.mode.title): \($0.scheduleText)" },
            pauseReason: pauseReason
        )
    }

    private func nextText(_ kind: AgentKind, enabled: Bool, working: Bool, paused: Bool) -> String {
        if paused { return "en pausa" }
        if !enabled { return "apagado" }
        if working { return "trabajando" }
        return engine.scheduler.nextRun(of: kind).map(TextTools.countdown) ?? "a pedido"
    }

    static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    func toggleEnabled(_ kind: AgentKind) {
        AgentStore.update(kind) { $0.enabled.toggle() }
        refresh()
    }

    func togglePractice(_ kind: AgentKind) {
        Practice.set(kind, on: !AgentStore.load(kind).practice, from: Self.panelOrigin)
        refresh()
    }

    static let panelOrigin = "el panel"

    func toggleAutoApprove(_ kind: AgentKind) {
        AutoSendConfirmation.toggle(kind)
        refresh()
    }

    func toggleSource(_ source: String) {
        var config = Config.load()
        config.setEnabled(source, !config.isEnabled(source))
        config.save()
        refresh()
    }

    func resume(_ kind: AgentKind) {
        engine.controller.resumeAgent(kind)
        refresh()
    }

    func runNow(_ kind: AgentKind) {
        engine.controller.runAgentNow(kind)
        refresh()
    }

    func editSettings(_ kind: AgentKind?) {
        onOpenSettings?(kind.map { .agent($0) })
    }

    func editContentAccounts() {
        onOpenSettings?(.content)
    }

    func editChannel() {
        onOpenSettings?(.channel)
    }

    func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            StatusMenu.info("No pude cambiar el inicio automático: \(error.localizedDescription)")
        }
        refresh()
    }

    func open(_ url: URL) {
        Paths.ensure()
        NSWorkspace.shared.open(url)
    }

    func openLog() {
        LogExport.openRecent()
    }
}
