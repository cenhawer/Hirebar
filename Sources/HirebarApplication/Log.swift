import HirebarDomain
import os

public struct Log: Sendable {
    public static let subsystem = "com.vmsoftware.hirebar"

    public enum Area: String, Sendable, CaseIterable {
        case telegram
        case ai = "ia"
        case portals = "portales"
        case media = "medios"
        case notifications = "notificaciones"
        case storage = "datos"
        case system = "sistema"
    }

    let logger: Logger

    public init(_ area: Area) {
        logger = Logger(subsystem: Self.subsystem, category: area.rawValue)
    }

    public init(agent: AgentKind) {
        logger = Logger(subsystem: Self.subsystem, category: agent.rawValue)
    }

    public func write(_ text: String) {
        logger.notice("\(text, privacy: .public)")
    }

    public static func write(_ text: String) {
        Log(.system).write(text)
    }
}
