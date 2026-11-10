import Foundation
import HirebarDomain

public protocol ExecutionStateStore: Sendable {
    func proposals(batch: String) -> [Proposal]
    func saveProposals(_ proposals: [Proposal], batch: String) throws
    func approvedItems(batch: String) -> [ApprovedItem]
    func saveApproved(_ items: [ApprovedItem], batch: String, agent: AgentID) throws
    func releaseApproval(batch: String) throws
    func actionLog(batch: String) -> ActionLogReading
    func discardActionLog(batch: String) throws
    func save(_ verification: ExecutionVerification, agent: AgentID) throws
    func consumedActions(agent: AgentID, since: Date) -> Int
    func contactedTargets(agent: AgentID) -> [Target]
    func seenProposals() -> [String: Date]
    func saveSeenProposals(_ seen: [String: Date]) throws
    func pauses() -> [AgentPause]
    func pause(_ pause: AgentPause) throws
    func resume(_ agent: AgentID) throws
    func removeRecords(before date: Date) throws
}

public protocol ExecutionAlerts: Sendable {
    func executionNeedsReview(agent: AgentID, verification: ExecutionVerification, pauseSaved: Bool)
}

public enum ActionLogFile {
    public static func name(batch: String) -> String { "\(batch).acciones.json" }
}
