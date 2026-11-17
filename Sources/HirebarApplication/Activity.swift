import Foundation
import HirebarDomain

public enum ActivityOutcome: String, CaseIterable, Sendable {
    case sent
    case rejected
    case practice

    public var title: String {
        switch self {
        case .sent: return String(localized: "Enviado")
        case .rejected: return String(localized: "No coincidió con lo aprobado")
        case .practice: return String(localized: "Práctica: no se envió")
        }
    }
}

public struct ActivityEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let agent: AgentID
    public let batch: String
    public let action: ActionKind
    public let target: Target
    public let text: String?
    public let at: Date
    public let outcome: ActivityOutcome

    public init(
        agent: AgentID, batch: String, action: ActionKind, target: Target, text: String?, at: Date, outcome: ActivityOutcome
    ) {
        self.agent = agent
        self.batch = batch
        self.action = action
        self.target = target
        self.text = text
        self.at = at
        self.outcome = outcome
        id = "\(batch)|\(outcome.rawValue)|\(action.rawValue)|\(target.displayText)|\(at.timeIntervalSince1970)"
    }
}

public enum ActivityPeriod: String, CaseIterable, Sendable {
    case today
    case week
    case month
    case all

    static let weekDays = 7
    static let monthDays = 30

    public var title: String {
        switch self {
        case .today: return String(localized: "Hoy")
        case .week: return String(localized: "Últimos 7 días")
        case .month: return String(localized: "Últimos 30 días")
        case .all: return String(localized: "Todo")
        }
    }

    public func start(before now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .today: return today
        case .week: return calendar.date(byAdding: .day, value: 1 - Self.weekDays, to: today)
        case .month: return calendar.date(byAdding: .day, value: 1 - Self.monthDays, to: today)
        case .all: return nil
        }
    }
}

public struct ActivityFilter: Sendable {
    public var agent: AgentID?
    public var period: ActivityPeriod

    public init(agent: AgentID? = nil, period: ActivityPeriod = .week) {
        self.agent = agent
        self.period = period
    }

    public func apply(_ entries: [ActivityEntry], now: Date, calendar: Calendar = .current) -> [ActivityEntry] {
        let start = period.start(before: now, calendar: calendar)
        return entries.filter { entry in
            (agent == nil || entry.agent == agent) && (start.map { entry.at >= $0 } ?? true)
        }
        .sorted { $0.at > $1.at }
    }
}

public protocol ActivityRepository: Sendable {
    func activity() -> [ActivityEntry]
}

extension ActionKind {
    public var activityTitle: String {
        switch self {
        case .apply: return String(localized: "Postulación")
        case .sendProposal: return String(localized: "Propuesta")
        case .sendFollowUp: return String(localized: "Seguimiento")
        case .sendEmail: return String(localized: "Correo")
        case .draftEmail: return String(localized: "Borrador de correo")
        case .publish: return String(localized: "Publicación")
        case .replyToClient: return String(localized: "Respuesta a cliente")
        }
    }
}
