import Foundation

public enum ReviewOutcome: String, Codable, Sendable {
    case approvedAsIs
    case corrected
    case skippedTimeout
    case skippedFailure
}

public struct ReviewedDraft: Codable, Sendable {
    public let batch: String
    public let outcome: ReviewOutcome
    public let original: [Proposal]
    public let final: [Proposal]
    public let summary: String
    public let reviewedAt: Date

    public init(batch: String, outcome: ReviewOutcome, original: [Proposal], final: [Proposal], summary: String, reviewedAt: Date) {
        self.batch = batch
        self.outcome = outcome
        self.original = original
        self.final = final
        self.summary = summary
        self.reviewedAt = reviewedAt
    }
}
