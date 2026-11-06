import Foundation
import HirebarDomain

public struct ExecutionGuard: Sendable {
    let store: ExecutionStateStore
    let alerts: ExecutionAlerts
    let now: @Sendable () -> Date

    public init(store: ExecutionStateStore, alerts: ExecutionAlerts, now: @escaping @Sendable () -> Date = Date.init) {
        self.store = store
        self.alerts = alerts
        self.now = now
    }

    public func pause(of agent: AgentID) -> AgentPause? {
        store.pauses().first { $0.agent == agent }
    }

    public func resume(_ agent: AgentID) throws {
        try store.resume(agent)
    }

    public func remainingQuota(of agent: AgentID, dailyLimit: Int?, calendar: Calendar = .current) -> Int? {
        guard let dailyLimit else { return nil }
        let startOfDay = calendar.startOfDay(for: now())
        return max(0, dailyLimit - store.completedActions(agent: agent, since: startOfDay))
    }

    public func approve(_ proposals: [Proposal], batch: String, approvedBy: Approver) throws -> [ApprovedItem] {
        let moment = now()
        let items = proposals.map { ApprovedItem(proposal: $0, batch: batch, approvedAt: moment, approvedBy: approvedBy) }
        try store.saveApproved(items, batch: batch)
        return items
    }

    @discardableResult
    public func verify(batch: String, agent: AgentID) -> ExecutionVerification {
        let verification = ExecutionVerifier.verify(
            batch: batch, approved: store.approvedItems(batch: batch), reading: store.actionLog(batch: batch))
        try? store.save(verification, agent: agent)
        if verification.requiresPause {
            let reason =
                verification.unverifiedReason?.rawValue ?? verification.violations.compactMap(\.reason?.rawValue).joined(separator: ",")
            try? store.pause(AgentPause(agent: agent, batch: batch, reason: reason, since: now()))
            alerts.executionNeedsReview(agent: agent, verification: verification)
        }
        return verification
    }
}
