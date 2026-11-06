import HirebarDomain

public protocol ExecutionStateStore: Sendable {
    func approvedItems(batch: String) -> [ApprovedItem]
    func saveApproved(_ items: [ApprovedItem], batch: String) throws
    func actionLog(batch: String) -> ActionLogReading
    func save(_ verification: ExecutionVerification) throws
    func pauses() -> [AgentPause]
    func pause(_ pause: AgentPause) throws
    func resume(_ agent: AgentID) throws
}
