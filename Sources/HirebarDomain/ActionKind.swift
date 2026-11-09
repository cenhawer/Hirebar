public enum ActionKind: String, Codable, CaseIterable, Sendable {
    case apply
    case sendProposal
    case sendFollowUp
    case sendEmail
    case draftEmail
    case publish
    case replyToClient

    public var requiresApprovedText: Bool {
        switch self {
        case .sendEmail, .draftEmail, .sendFollowUp, .replyToClient: return true
        case .apply, .sendProposal, .publish: return false
        }
    }

    public var alwaysNeedsApproval: Bool {
        self == .publish || self == .replyToClient
    }

    public var requiresPriorContact: Bool {
        self == .sendFollowUp
    }
}
