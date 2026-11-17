import Foundation

public enum ActionOutcome: String, Codable, Sendable {
    case done
    case pending
    case discarded
}

public struct ActionRecord: Codable, Hashable, Sendable {
    public let itemId: String
    public let action: ActionKind
    public let target: Target
    public let sentText: String?
    public let outcome: ActionOutcome
    public let reason: String?
    public let at: Date

    public init(
        itemId: String,
        action: ActionKind,
        target: Target,
        sentText: String? = nil,
        outcome: ActionOutcome,
        reason: String? = nil,
        at: Date
    ) {
        self.itemId = itemId
        self.action = action
        self.target = target
        self.sentText = sentText
        self.outcome = outcome
        self.reason = reason
        self.at = at
    }
}

public struct ActionLog: Codable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let batch: String
    public let actions: [ActionRecord]

    public init(batch: String, actions: [ActionRecord]) {
        schemaVersion = Self.currentSchemaVersion
        self.batch = batch
        self.actions = actions
    }
}
