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

    public func approve(
        _ proposals: [Proposal],
        batch: String,
        approvedBy: Approver,
        agent: AgentID,
        dailyLimit: Int?
    ) throws -> ExecutionPlan {
        let moment = now()
        let items = proposals.map { ApprovedItem(proposal: $0, batch: batch, approvedAt: moment, approvedBy: approvedBy) }
        let held = items.filter { approvedBy == .autoSend && $0.proposal.action.alwaysNeedsApproval }
        let eligible = items.filter { !held.contains($0) }
        let plan = ExecutionPlanner.plan(eligible, remainingQuota: remainingQuota(of: agent, dailyLimit: dailyLimit))
        try store.saveApproved(plan.now, batch: batch)
        return ExecutionPlan(now: plan.now, deferred: plan.deferred + held)
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
