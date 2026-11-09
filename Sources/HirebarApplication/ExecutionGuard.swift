import Foundation
import HirebarDomain

public enum ExecutionGuardFailure: Error, Equatable, Sendable {
    case pauseNotSaved(AgentPause, ExecutionVerification)
    case verificationNotSaved(ExecutionVerification)
}

public struct ExecutionGuard: Sendable {
    let store: ExecutionStateStore
    let alerts: ExecutionAlerts
    let rules: TargetRules
    let now: @Sendable () -> Date

    public init(
        store: ExecutionStateStore,
        alerts: ExecutionAlerts,
        rules: TargetRules = .strict,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.store = store
        self.alerts = alerts
        self.rules = rules
        self.now = now
    }

    public func pause(of agent: AgentID) -> AgentPause? {
        store.pauses().first { $0.agent == agent }
    }

    public func pauses() -> [AgentPause] {
        store.pauses()
    }

    public func resume(_ agent: AgentID) throws {
        try store.resume(agent)
    }

    public func remainingQuota(of agent: AgentID, dailyLimit: Int?, calendar: Calendar = .current) -> Int? {
        guard let dailyLimit else { return nil }
        let startOfDay = calendar.startOfDay(for: now())
        return max(0, dailyLimit - store.consumedActions(agent: agent, since: startOfDay))
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
        let contacted = Set(store.contactedTargets(agent: agent).map { $0.normalized(using: rules) })
        let held = approvedBy == .autoSend ? items.filter { needsPerson($0.proposal, contacted: contacted) } : []
        let eligible = items.filter { !held.contains($0) }
        let plan = ExecutionPlanner.plan(eligible, remainingQuota: remainingQuota(of: agent, dailyLimit: dailyLimit))
        if plan.now.isEmpty {
            try store.releaseApproval(batch: batch)
        } else {
            try store.saveApproved(plan.now, batch: batch, agent: agent)
        }
        return ExecutionPlan(now: plan.now, deferred: plan.deferred, held: held)
    }

    public func approvedItems(batch: String) -> [ApprovedItem] {
        store.approvedItems(batch: batch)
    }

    public func release(batch: String) throws {
        try store.releaseApproval(batch: batch)
    }

    public func prepareRun(batch: String) throws {
        try store.discardActionLog(batch: batch)
    }

    public func hasActionLog(batch: String) -> Bool {
        if case .missing = store.actionLog(batch: batch) { return false }
        return true
    }

    @discardableResult
    public func verify(batch: String, agent: AgentID) throws -> ExecutionVerification {
        let verification = ExecutionVerifier.verify(
            batch: batch, approved: store.approvedItems(batch: batch), reading: store.actionLog(batch: batch), rules: rules)
        let verificationSaved = (try? store.save(verification, agent: agent)) != nil
        if verification.requiresPause {
            let reason =
                verification.unverifiedReason?.rawValue ?? verification.violations.compactMap(\.reason?.rawValue).joined(separator: ",")
            let pause = AgentPause(agent: agent, batch: batch, reason: reason, since: now())
            let pauseSaved = (try? store.pause(pause)) != nil
            alerts.executionNeedsReview(agent: agent, verification: verification, pauseSaved: pauseSaved)
            if !pauseSaved { throw ExecutionGuardFailure.pauseNotSaved(pause, verification) }
        }
        if !verificationSaved { throw ExecutionGuardFailure.verificationNotSaved(verification) }
        return verification
    }

    func needsPerson(_ proposal: Proposal, contacted: Set<Target>) -> Bool {
        if proposal.action.alwaysNeedsApproval { return true }
        return proposal.action.requiresPriorContact && !contacted.contains(proposal.target.normalized(using: rules))
    }
}
