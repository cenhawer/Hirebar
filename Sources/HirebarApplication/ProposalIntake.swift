import Foundation
import HirebarDomain

public struct ProposalIntakeResult: Equatable, Sendable {
    public let fresh: [Proposal]
    public let rejected: [Proposal]
    public let seen: [String: Date]
}

public enum ProposalIntake {
    public static func accept(
        _ proposals: [Proposal],
        allowed: Set<ActionKind>,
        seen: [String: Date],
        now: Date,
        window: TimeInterval
    ) -> ProposalIntakeResult {
        var remembered = seen.filter { now.timeIntervalSince($0.value) < window }
        var fresh: [Proposal] = []
        for proposal in proposals where allowed.contains(proposal.action) {
            let key = proposal.target.normalized.displayText
            guard remembered[key] == nil else { continue }
            remembered[key] = now
            fresh.append(proposal)
        }
        return ProposalIntakeResult(fresh: fresh, rejected: proposals.filter { !allowed.contains($0.action) }, seen: remembered)
    }
}
