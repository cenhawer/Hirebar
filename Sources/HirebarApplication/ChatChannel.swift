import Foundation
import HirebarDomain

public struct ChatMessage: Sendable {
    public let chatId: Int64
    public let text: String
    public let replyTo: Int?
    public let callbackId: String?
    public var sender: ChannelSender?
    public var audioFileId: String?
    public var audioExtension: String
    public var audioBytes: Int?
    public var audioSeconds: Int?

    public init(
        chatId: Int64, text: String, replyTo: Int?, callbackId: String?, sender: ChannelSender? = nil, audioFileId: String? = nil,
        audioExtension: String = "oga", audioBytes: Int? = nil, audioSeconds: Int? = nil
    ) {
        self.chatId = chatId
        self.text = text
        self.replyTo = replyTo
        self.callbackId = callbackId
        self.sender = sender
        self.audioFileId = audioFileId
        self.audioExtension = audioExtension
        self.audioBytes = audioBytes
        self.audioSeconds = audioSeconds
    }
}

public enum BotCheck: Equatable, Sendable {
    case valid(username: String)
    case rejected
    case unreachable
    case notSaved
}

public typealias ChatButtons = [[(String, String)]]

public protocol ChatChannel: AnyObject, Sendable {
    var onMessage: (@MainActor (ChatMessage) -> Void)? { get set }
    var onTokenStateChange: (@MainActor () -> Void)? { get set }
    var isConfigured: Bool { get }
    var tokenRejected: Bool { get }
    func start()
    func checkToken(_ token: String) async -> BotCheck
    func saveToken(_ token: String) -> Bool
    func removeToken() -> Bool
    func botUsername() async -> String?
    func chatName(_ chatId: Int64) async -> String?
    func send(_ text: String, chatId: Int64, buttons: ChatButtons, completion: (@MainActor @Sendable (Int?) -> Void)?)
    func sendDocument(_ file: URL, caption: String, chatId: Int64)
    func sendPhotos(_ files: [URL], caption: String, chatId: Int64, completion: (@MainActor @Sendable () -> Void)?)
    func sendVideo(_ file: URL, caption: String, chatId: Int64, completion: (@MainActor @Sendable () -> Void)?)
    func download(fileId: String, to target: URL, maxBytes: Int?) -> Bool
    func answerCallback(_ id: String, text: String?)
    func removeButtons(chatId: Int64, messageId: Int)
}

extension ChatChannel {
    public func send(_ text: String, chatId: Int64, buttons: ChatButtons = []) {
        send(text, chatId: chatId, buttons: buttons, completion: nil)
    }

    public func send(_ text: String, chatId: Int64, completion: @escaping @MainActor @Sendable (Int?) -> Void) {
        send(text, chatId: chatId, buttons: [], completion: completion)
    }
}

public protocol ChatOffsetStore: Sendable {
    func chatOffset() -> Int
    func saveChatOffset(_ offset: Int)
}

public protocol DesktopNotifications: Sendable {
    func show(title: String, body: String)
}

public struct EngineAdapters {
    public let chat: ChatChannel
    public let desktop: DesktopNotifications
    public let clock: Clock
    public let aiRunner: AIRunner
    public let media: MediaRenderer
    public let resources: EngineResources

    public init(
        chat: ChatChannel, desktop: DesktopNotifications, clock: Clock, aiRunner: AIRunner, media: MediaRenderer,
        resources: EngineResources
    ) {
        self.chat = chat
        self.desktop = desktop
        self.clock = clock
        self.aiRunner = aiRunner
        self.media = media
        self.resources = resources
    }
}
