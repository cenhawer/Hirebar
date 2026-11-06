import HirebarDomain

public struct ExecutionPlan: Equatable, Sendable {
    public let now: [ApprovedItem]
    public let deferred: [ApprovedItem]

    public init(now: [ApprovedItem], deferred: [ApprovedItem]) {
        self.now = now
        self.deferred = deferred
    }
}

public enum ExecutionPlanner {
    public static func plan(_ approved: [ApprovedItem], remainingQuota: Int?) -> ExecutionPlan {
        guard let remainingQuota else { return ExecutionPlan(now: approved, deferred: []) }
        let room = max(0, remainingQuota)
        return ExecutionPlan(now: Array(approved.prefix(room)), deferred: Array(approved.dropFirst(room)))
    }
}
