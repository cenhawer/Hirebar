import Foundation
import HirebarDomain

public protocol ExecutionStateStore: Sendable {
    func proposals(batch: String) -> [Proposal]
    func saveProposals(_ proposals: [Proposal], batch: String) throws
    func approvedItems(batch: String) -> [ApprovedItem]
    func saveApproved(_ items: [ApprovedItem], batch: String) throws
    func actionLog(batch: String) -> ActionLogReading
    func save(_ verification: ExecutionVerification, agent: AgentID) throws
    func completedActions(agent: AgentID, since: Date) -> Int
    func pauses() -> [AgentPause]
    func pause(_ pause: AgentPause) throws
    func resume(_ agent: AgentID) throws
}

public protocol ExecutionAlerts: Sendable {
    func executionNeedsReview(agent: AgentID, verification: ExecutionVerification)
}
