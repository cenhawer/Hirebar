import CryptoKit
import Foundation
import HirebarDomain

public struct ProposalIntakeResult: Equatable, Sendable {
    public let fresh: [Proposal]
    public let rejected: [Proposal]
    public let seen: [String: Date]
}

public struct ProposalIntake: Sendable {
    let window: TimeInterval
    let rules: TargetRules

    public init(window: TimeInterval, rules: TargetRules) {
        self.window = window
        self.rules = rules
    }

    public func accept(_ proposals: [Proposal], allowed: Set<ActionKind>, seen: [String: Date], now: Date) -> ProposalIntakeResult {
        var remembered = seen.filter { now.timeIntervalSince($0.value) < window }
        var fresh: [Proposal] = []
        for proposal in proposals where allowed.contains(proposal.action) {
            let key = Self.seenKey(for: proposal, rules: rules)
            guard remembered[key] == nil else { continue }
            remembered[key] = now
            fresh.append(proposal)
        }
        return ProposalIntakeResult(fresh: fresh, rejected: proposals.filter { !allowed.contains($0.action) }, seen: remembered)
    }

    public static func seenKey(for proposal: Proposal, rules: TargetRules) -> String {
        let base = proposal.action.rawValue + " " + proposal.target.normalized(using: rules).displayText
        guard proposal.action.requiresApprovedText else { return base }
        let text = ExecutionVerifier.comparable(proposal.text)
        let digest = SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
        return base + " " + digest
    }
}
