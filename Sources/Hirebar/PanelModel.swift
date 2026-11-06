import AppKit
import HirebarCore
import HirebarEngine
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
    @Published var agents: [AgentCardData] = []
    @Published var claude = "en espera"
    @Published var aiName = "Claude"
    @Published var claudeBusy = false
    @Published var telegram = ""
    @Published var telegramReady = false
    @Published var opensAtLogin = false

    var onConfigureTelegram: (() -> Void)?
    var onSendTest: (() -> Void)?
    var onForgetChat: (() -> Void)?
    var onQuit: (() -> Void)?
    var onOpenSettings: ((SettingsPage?) -> Void)?

    func refresh() {
        let running = Controller.shared.runningAgent
        agents = AgentKind.allCases.map { card($0, running: running) }
        claude = Controller.shared.status
        aiName = AI.capitalizedName
        claudeBusy = !Controller.shared.isIdle
        let config = Config.load()
        if !Telegram.shared.isConfigured {
            telegram = "Telegram sin configurar"
            telegramReady = false
        } else if config.chatId == 0 {
            telegram = "Envía /start a tu bot"
            telegramReady = false
        } else {
            telegram = "Telegram conectado"
            telegramReady = true
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func card(_ kind: AgentKind, running: AgentKind?) -> AgentCardData {
        let agent = AgentStore.load(kind)
        let config = Config.load()
        let working = running == kind
        var status: String
        switch kind {
        case .jobs: status = "Última búsqueda: \(JobRadar.shared.status)"
        case .freelance: status = "Última búsqueda: \(FreelanceRadar.shared.status)"
        case .profile: status = "\(Profile.load().cvVariants.count) hojas de vida · escribe \"logro\" o \"hv\" en Telegram"
        case .clients, .content, .analyst: status = agent.tasks.first.map { "Corre \($0.scheduleText)" } ?? "Sin horario"
        }
        if working { status = Self.capitalized(Controller.shared.status) }
        let pauseReason = Controller.shared.pauseReason(of: kind)
        let next: String
        if pauseReason != nil {
            next = "en pausa"
        } else if !agent.enabled {
            next = "apagado"
        } else if working {
            next = "trabajando"
        } else if let date = Scheduler.shared.nextRun(of: kind) {
            next = TextTools.countdown(date)
        } else {
            next = "a pedido"
        }
        var stats = WeeklyStats.lines(for: kind)
        if kind == .freelance {
            stats += ["Workana \(Quotas.describe("workana"))", "Freelancer \(Quotas.describe("freelancer"))"]
        }
        if !stats.isEmpty && [.jobs, .freelance, .clients].contains(kind) { stats[0] = "Esta semana: " + stats[0] }
        let ids = kind == .jobs ? Config.jobSources : kind == .freelance ? Config.freelanceSources : []
        return AgentCardData(id: kind, name: agent.name, purpose: agent.purpose, status: status, next: next,
                             enabled: agent.enabled, autoApprove: agent.autoApprove, working: working, stats: stats,
                             sources: ids.map { SourceToggle(id: $0, title: StatusMenu.sourceTitles[$0] ?? $0, on: config.isEnabled($0)) },
                             schedule: agent.tasks.map { "\($0.mode.title): \($0.scheduleText)" },
                             pauseReason: pauseReason)
    }

    static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    func toggleEnabled(_ kind: AgentKind) {
        AgentStore.update(kind) { $0.enabled.toggle() }
        refresh()
    }

    func toggleAutoApprove(_ kind: AgentKind) {
        AgentStore.update(kind) { $0.autoApprove.toggle() }
        refresh()
    }

    func toggleSource(_ source: String) {
        var config = Config.load()
        config.setEnabled(source, !config.isEnabled(source))
        config.save()
        refresh()
    }

    func resume(_ kind: AgentKind) {
        Controller.shared.resumeAgent(kind)
        refresh()
    }

    func runNow(_ kind: AgentKind) {
        Controller.shared.runAgentNow(kind)
        refresh()
    }

    func editSettings(_ kind: AgentKind?) {
        onOpenSettings?(kind.map { .agent($0) })
    }

    func editContentAccounts() {
        onOpenSettings?(.content)
    }

    func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            StatusMenu.shared.info("No pude cambiar el inicio automático: \(error.localizedDescription)")
        }
        refresh()
    }

    func open(_ url: URL) {
        Paths.ensure()
        NSWorkspace.shared.open(url)
    }

    func openLog() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: Paths.log.path) {
            try? fm.createDirectory(at: Paths.logs, withIntermediateDirectories: true)
            fm.createFile(atPath: Paths.log.path, contents: nil)
        }
        NSWorkspace.shared.open(Paths.log)
    }
}
