import Foundation

public enum Approver: String, Codable, Sendable {
    case person
    case autoSend
}

public struct ApprovedItem: Codable, Hashable, Sendable {
    public let proposal: Proposal
    public let batch: String
    public let approvedAt: Date
    public let approvedBy: Approver

    public init(proposal: Proposal, batch: String, approvedAt: Date, approvedBy: Approver) {
        self.proposal = proposal
        self.batch = batch
        self.approvedAt = approvedAt
        self.approvedBy = approvedBy
    }
}
