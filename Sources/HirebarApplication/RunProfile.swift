public enum RunProfile: Equatable, Sendable {
    case read
    case draft(writablePaths: [String])
    case act

    public var phase: String {
        switch self {
        case .read: return "read"
        case .draft: return "draft"
        case .act: return "act"
        }
    }

    public var canWrite: Bool {
        self != .read
    }

    public var canAct: Bool {
        self == .act
    }
}
