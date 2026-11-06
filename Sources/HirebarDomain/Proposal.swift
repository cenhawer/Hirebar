public enum FitLevel: String, Codable, Sendable {
    case strong = "ENCAJA"
    case stretch = "RETO"
}

public struct Proposal: Codable, Hashable, Sendable {
    public let id: String
    public let action: ActionKind
    public let target: Target
    public let title: String
    public let source: String
    public let text: String?
    public let fit: FitLevel?

    public init(
        id: String,
        action: ActionKind,
        target: Target,
        title: String,
        source: String,
        text: String? = nil,
        fit: FitLevel? = nil
    ) {
        self.id = id
        self.action = action
        self.target = target
        self.title = title
        self.source = source
        self.text = text
        self.fit = fit
    }

    public var isComplete: Bool {
        guard !id.isEmpty else { return false }
        guard action.requiresText else { return true }
        return !(text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
