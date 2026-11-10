import Foundation
import HirebarApplication

final class TestChatChannel: ChatChannel, @unchecked Sendable {
    var onMessage: (@MainActor (ChatMessage) -> Void)?
    var onTokenStateChange: (@MainActor () -> Void)?
    let configured: () -> Bool
    let rejected: () -> Bool
    let deliver: (String, Int64) -> Void
    let save: (String) -> Bool
    let remove: () -> Bool
    let begin: () -> Void
    var check: BotCheck = .unreachable

    init(
        isConfigured: @escaping () -> Bool = { false },
        tokenRejected: @escaping () -> Bool = { false },
        send: @escaping (String, Int64) -> Void = { _, _ in },
        saveToken: @escaping (String) -> Bool = { _ in false },
        removeToken: @escaping () -> Bool = { false },
        start: @escaping () -> Void = {}
    ) {
        configured = isConfigured
        rejected = tokenRejected
        deliver = send
        save = saveToken
        remove = removeToken
        begin = start
    }

    var isConfigured: Bool { configured() }
    var tokenRejected: Bool { rejected() }
    func start() { begin() }
    func checkToken(_ token: String) async -> BotCheck { check }
    func saveToken(_ token: String) -> Bool { save(token) }
    func removeToken() -> Bool { remove() }
    func botUsername() async -> String? { nil }
    func chatName(_ chatId: Int64) async -> String? { nil }
    func send(_ text: String, chatId: Int64, buttons: ChatButtons, completion: (@MainActor @Sendable (Int?) -> Void)?) {
        deliver(text, chatId)
    }
    func sendDocument(_ file: URL, caption: String, chatId: Int64) {}
    func sendPhotos(_ files: [URL], caption: String, chatId: Int64, completion: (@MainActor @Sendable () -> Void)?) {
        MainActor.assumeIsolated { completion?() }
    }
    func sendVideo(_ file: URL, caption: String, chatId: Int64, completion: (@MainActor @Sendable () -> Void)?) {
        MainActor.assumeIsolated { completion?() }
    }
    func download(fileId: String, to target: URL, maxBytes: Int?) -> Bool { false }
    func answerCallback(_ id: String, text: String?) {}
    func removeButtons(chatId: Int64, messageId: Int) {}
}

struct TestDesktopNotifications: DesktopNotifications {
    func show(title: String, body: String) {}
}
