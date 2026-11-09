import HirebarDomain
import XCTest

@testable import HirebarCore

final class TelegramSenderTests: XCTestCase {
    func testMessagesCarryWhoSentThemFromWhichChatAndWhen() {
        let update: [String: Any] = [
            "update_id": 1,
            "message": [
                "message_id": 3, "date": 1_800_000_000, "text": "hola",
                "from": ["id": 7, "first_name": "Ana", "last_name": "Ruiz", "username": "ana"],
                "chat": ["id": 7, "type": "private"],
            ],
        ]
        let sender = Telegram.parse(update)?.sender
        XCTAssertEqual(sender?.userId, 7)
        XCTAssertEqual(sender?.chatId, 7)
        XCTAssertEqual(sender?.name, "Ana Ruiz")
        XCTAssertEqual(sender?.username, "ana")
        XCTAssertEqual(sender?.isPrivateChat, true)
        XCTAssertEqual(sender?.sentAt, Date(timeIntervalSince1970: 1_800_000_000))
    }

    func testButtonsCarryWhoPressedThemNotWhoReceivedTheMessage() {
        let update: [String: Any] = [
            "update_id": 2,
            "callback_query": [
                "id": "c1", "data": "si:b1", "from": ["id": 99, "first_name": "Otra"],
                "message": ["message_id": 4, "chat": ["id": 7, "type": "private"]],
            ],
        ]
        let message = Telegram.parse(update)
        XCTAssertEqual(message?.sender?.userId, 99)
        XCTAssertEqual(message?.sender?.chatId, 7)
        XCTAssertEqual(message?.text, "si:b1")
    }

    func testGroupMessagesAreMarkedAsNotPrivate() {
        let message: [String: Any] = [
            "message_id": 5,
            "date": 1,
            "text": "si",
            "from": ["id": 7, "first_name": "Ana"],
            "chat": ["id": -100, "type": "group"],
        ]
        XCTAssertEqual(Telegram.parse(["message": message])?.sender?.isPrivateChat, false)
    }

    func testOnlyTokensWithTheBotFatherShapeAreAccepted() {
        XCTAssertTrue(Telegram.looksLikeToken("123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw0"))
        XCTAssertFalse(Telegram.looksLikeToken("hola"))
        XCTAssertFalse(Telegram.looksLikeToken("123:corto"))
    }

    func testVoiceNotesCarryTheirSizeAndDuration() {
        let voice: [String: Any] = ["file_id": "f1", "file_size": 123_456, "duration": 42]
        let message: [String: Any] = [
            "message_id": 6,
            "date": 1,
            "voice": voice,
            "from": ["id": 7, "first_name": "Ana"],
            "chat": ["id": 7, "type": "private"],
        ]
        let parsed = Telegram.parse(["message": message])
        XCTAssertEqual(parsed?.audioBytes, 123_456)
        XCTAssertEqual(parsed?.audioSeconds, 42)
    }
}
