public enum ActionKind: String, Codable, CaseIterable, Sendable {
    case apply
    case sendProposal
    case sendFollowUp
    case sendEmail
    case draftEmail
    case publish
    case replyToClient

    public var requiresText: Bool {
        self != .apply
    }

    public var alwaysNeedsApproval: Bool {
        self == .publish || self == .replyToClient
    }
}
