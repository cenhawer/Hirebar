import Foundation
import HirebarDomain

public struct PairingCandidate: Equatable, Sendable {
    public let owner: ChannelOwner
    public let text: String

    public var hasUsername: Bool { !(owner.username ?? "").isEmpty }
}

public struct ChannelPairing: Equatable, Sendable {
    public let startedAt: Date
    public let window: TimeInterval
    public private(set) var declined: Set<Int64> = []
    public private(set) var queue: [PairingCandidate] = []

    static let clockTolerance: TimeInterval = 1

    public init(startedAt: Date, window: TimeInterval) {
        self.startedAt = startedAt
        self.window = window
    }

    public var current: PairingCandidate? { queue.first }

    public func isExpired(at moment: Date) -> Bool {
        moment.timeIntervalSince(startedAt) > window
    }

    public mutating func receive(_ sender: ChannelSender, text: String, at moment: Date) -> Bool {
        guard sender.isPrivateChat, !sender.viaButton, !isExpired(at: moment),
            sender.sentAt >= startedAt.addingTimeInterval(-Self.clockTolerance),
            !declined.contains(sender.userId), !queue.contains(where: { $0.owner.userId == sender.userId })
        else { return false }
        queue.append(PairingCandidate(owner: sender.asOwner, text: text))
        return true
    }

    public mutating func declineCurrent() {
        guard let rejected = queue.first else { return }
        declined.insert(rejected.owner.userId)
        queue.removeFirst()
    }
}
