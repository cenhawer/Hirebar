import Foundation

public struct ChannelOwner: Codable, Hashable, Sendable {
    public let userId: Int64
    public let chatId: Int64
    public let name: String
    public let username: String?

    public init(userId: Int64, chatId: Int64, name: String, username: String? = nil) {
        self.userId = userId
        self.chatId = chatId
        self.name = name
        self.username = username
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(Int64.self, forKey: .userId)
        chatId = try container.decode(Int64.self, forKey: .chatId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        username = try container.decodeIfPresent(String.self, forKey: .username)
    }
}

public struct ChannelSender: Hashable, Sendable {
    public let userId: Int64
    public let chatId: Int64
    public let name: String
    public let username: String?
    public let isPrivateChat: Bool
    public let sentAt: Date
    public let viaButton: Bool

    public init(
        userId: Int64,
        chatId: Int64,
        name: String,
        username: String?,
        isPrivateChat: Bool,
        sentAt: Date,
        viaButton: Bool = false
    ) {
        self.userId = userId
        self.chatId = chatId
        self.name = name
        self.username = username
        self.isPrivateChat = isPrivateChat
        self.sentAt = sentAt
        self.viaButton = viaButton
    }

    public var asOwner: ChannelOwner {
        ChannelOwner(userId: userId, chatId: chatId, name: name, username: username)
    }
}
