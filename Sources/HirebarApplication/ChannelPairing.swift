import Foundation
import HirebarDomain

public struct ChannelPairing: Equatable, Sendable {
    public let startedAt: Date
    public let window: TimeInterval
    public private(set) var declined: Set<Int64> = []

    public init(startedAt: Date, window: TimeInterval) {
        self.startedAt = startedAt
        self.window = window
    }

    public func isExpired(at moment: Date) -> Bool {
        moment.timeIntervalSince(startedAt) > window
    }

    public func candidate(from sender: ChannelSender, at moment: Date) -> ChannelOwner? {
        guard sender.isPrivateChat, !isExpired(at: moment), sender.sentAt >= startedAt.addingTimeInterval(-Self.clockTolerance),
            !declined.contains(sender.userId)
        else { return nil }
        return sender.asOwner
    }

    public mutating func decline(_ candidate: ChannelOwner) {
        declined.insert(candidate.userId)
    }

    static let clockTolerance: TimeInterval = 1
}
