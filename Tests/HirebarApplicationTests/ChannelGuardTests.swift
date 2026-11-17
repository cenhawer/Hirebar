import Foundation
import HirebarDomain
import XCTest

@testable import HirebarApplication
@testable import HirebarDomain

final class ChannelGuardTests: XCTestCase {
    let moment = Date(timeIntervalSince1970: 1_800_000_000)
    let owner = ChannelOwner(userId: 7, chatId: 7, name: "Ana", username: "ana")

    func sender(user: Int64 = 7, chat: Int64 = 7, privateChat: Bool = true) -> ChannelSender {
        ChannelSender(userId: user, chatId: chat, name: "x", username: nil, isPrivateChat: privateChat, sentAt: moment)
    }

    func testOnlyTheAnchoredAccountInItsChatIsAllowed() {
        var guardian = ChannelGuard(messagesPerMinute: 30)
        XCTAssertEqual(guardian.check(sender(), owner: owner, now: moment), .allowed)
        XCTAssertEqual(guardian.check(sender(user: 8, chat: 8), owner: owner, now: moment), .notOwner)
        XCTAssertEqual(guardian.check(sender(user: 7, chat: -100), owner: owner, now: moment), .notOwner)
        XCTAssertEqual(guardian.check(sender(user: 8, chat: 7), owner: owner, now: moment), .notOwner)
    }

    func testWithoutAnAnchoredAccountNobodyIsAllowed() {
        var guardian = ChannelGuard(messagesPerMinute: 30)
        XCTAssertEqual(guardian.check(sender(), owner: nil, now: moment), .notOwner)
    }

    func testMessagesBeyondTheLimitPerMinuteAreIgnoredUntilTheMinutePasses() {
        var guardian = ChannelGuard(messagesPerMinute: 2)
        XCTAssertEqual(guardian.check(sender(), owner: owner, now: moment), .allowed)
        XCTAssertEqual(guardian.check(sender(), owner: owner, now: moment.addingTimeInterval(10)), .allowed)
        XCTAssertEqual(guardian.check(sender(), owner: owner, now: moment.addingTimeInterval(20)), .tooMany)
        XCTAssertEqual(guardian.check(sender(), owner: owner, now: moment.addingTimeInterval(61)), .allowed)
    }
}

final class ChannelPairingTests: XCTestCase {
    let moment = Date(timeIntervalSince1970: 1_800_000_000)

    func sender(
        user: Int64 = 7,
        privateChat: Bool = true,
        sentAt: Date,
        viaButton: Bool = false,
        username: String? = "ana"
    ) -> ChannelSender {
        ChannelSender(
            userId: user, chatId: user, name: "Ana", username: username, isPrivateChat: privateChat, sentAt: sentAt, viaButton: viaButton)
    }

    func testAPrivateMessageSentAfterStartingIsProposedWithItsText() {
        var pairing = ChannelPairing(startedAt: moment, window: 600)
        XCTAssertTrue(pairing.receive(sender(sentAt: moment.addingTimeInterval(5)), text: "hola", at: moment.addingTimeInterval(6)))
        XCTAssertEqual(pairing.current?.owner, ChannelOwner(userId: 7, chatId: 7, name: "Ana", username: "ana"))
        XCTAssertEqual(pairing.current?.text, "hola")
        XCTAssertEqual(pairing.current?.hasUsername, true)
    }

    func testOldGroupLateAndButtonMessagesAreNotProposed() {
        var pairing = ChannelPairing(startedAt: moment, window: 600)
        XCTAssertFalse(pairing.receive(sender(sentAt: moment.addingTimeInterval(-120)), text: "hola", at: moment.addingTimeInterval(1)))
        XCTAssertFalse(pairing.receive(sender(privateChat: false, sentAt: moment), text: "hola", at: moment))
        XCTAssertFalse(pairing.receive(sender(sentAt: moment, viaButton: true), text: "si:b1", at: moment))
        XCTAssertFalse(pairing.receive(sender(sentAt: moment.addingTimeInterval(601)), text: "hola", at: moment.addingTimeInterval(601)))
        XCTAssertTrue(pairing.isExpired(at: moment.addingTimeInterval(601)))
        XCTAssertNil(pairing.current)
    }

    func testDecliningShowsTheNextCandidateAndNeverTheDeclinedOneAgain() {
        var pairing = ChannelPairing(startedAt: moment, window: 600)
        XCTAssertTrue(pairing.receive(sender(user: 8, sentAt: moment, username: nil), text: "hola", at: moment))
        XCTAssertTrue(pairing.receive(sender(user: 7, sentAt: moment), text: "soy yo", at: moment))
        XCTAssertFalse(pairing.receive(sender(user: 7, sentAt: moment), text: "otra vez", at: moment))
        XCTAssertEqual(pairing.current?.hasUsername, false)
        pairing.declineCurrent()
        XCTAssertEqual(pairing.current?.owner.userId, 7)
        XCTAssertFalse(pairing.receive(sender(user: 8, sentAt: moment), text: "hola", at: moment))
    }
}
