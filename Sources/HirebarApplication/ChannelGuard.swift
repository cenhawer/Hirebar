import Foundation
import HirebarDomain

public enum ChannelDecision: Equatable, Sendable {
    case allowed
    case notOwner
    case tooMany
}

public struct ChannelGuard: Sendable {
    let messagesPerMinute: Int
    private var recent: [Date] = []

    public init(messagesPerMinute: Int) {
        self.messagesPerMinute = messagesPerMinute
    }

    static let window: TimeInterval = 60

    public mutating func check(_ sender: ChannelSender, owner: ChannelOwner?, now: Date) -> ChannelDecision {
        guard let owner, sender.userId == owner.userId, sender.chatId == owner.chatId else { return .notOwner }
        recent.removeAll { now.timeIntervalSince($0) >= Self.window }
        guard recent.count < messagesPerMinute else { return .tooMany }
        recent.append(now)
        return .allowed
    }
}
