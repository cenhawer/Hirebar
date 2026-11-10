import Foundation
import HirebarDomain
import HirebarStorage
import XCTest

@testable import HirebarApplication

@MainActor
final class NotifierTests: XCTestCase {
    final class MemoryConfig: ConfigRepository, @unchecked Sendable {
        var config = Config()
        func load() -> Config { config }
        func save(_ config: Config) { self.config = config }
    }

    final class RecordingDesktop: DesktopNotifications, @unchecked Sendable {
        var shown: [String] = []
        func show(title: String, body: String) { shown.append(body) }
    }

    var sent: [(String, Int64)] = []
    var configured = false
    let config = MemoryConfig()
    let desktop = RecordingDesktop()

    var notifier: Notifier {
        let chat = TestChatChannel(
            isConfigured: { [unowned self] in self.configured }, send: { [unowned self] in self.sent.append(($0, $1)) })
        return Notifier(chat: chat, desktop: desktop, config: config, batches: FileBatchRepository())
    }

    func testWithoutAChannelTheNoticeGoesToTheMacNotifications() {
        notifier.tell("Lista lista")
        XCTAssertEqual(desktop.shown, ["Lista lista"])
        XCTAssertTrue(sent.isEmpty)
    }

    func testWithALinkedChannelTheNoticeGoesToTheOwnerChat() {
        configured = true
        config.config.channelOwner = ChannelOwner(userId: 7, chatId: 42, name: "Ana")
        notifier.tell("Lista lista")
        XCTAssertEqual(sent.map(\.1), [42])
        XCTAssertTrue(desktop.shown.isEmpty)
    }
}
