import Foundation

public struct AgentPause: Codable, Hashable, Sendable {
    public let agent: AgentID
    public let batch: String
    public let reason: String
    public let since: Date

    public init(agent: AgentID, batch: String, reason: String, since: Date) {
        self.agent = agent
        self.batch = batch
        self.reason = reason
        self.since = since
    }
}
