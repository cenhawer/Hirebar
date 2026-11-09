import Foundation
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

    func sender(user: Int64 = 7, privateChat: Bool = true, sentAt: Date) -> ChannelSender {
        ChannelSender(userId: user, chatId: user, name: "Ana", username: "ana", isPrivateChat: privateChat, sentAt: sentAt)
    }

    func testAPrivateMessageSentAfterStartingIsProposed() {
        let pairing = ChannelPairing(startedAt: moment, window: 600)
        let proposed = pairing.candidate(from: sender(sentAt: moment.addingTimeInterval(5)), at: moment.addingTimeInterval(6))
        XCTAssertEqual(proposed, ChannelOwner(userId: 7, chatId: 7, name: "Ana", username: "ana"))
    }

    func testOldGroupAndLateMessagesAreNotProposed() {
        let pairing = ChannelPairing(startedAt: moment, window: 600)
        XCTAssertNil(pairing.candidate(from: sender(sentAt: moment.addingTimeInterval(-120)), at: moment.addingTimeInterval(1)))
        XCTAssertNil(pairing.candidate(from: sender(privateChat: false, sentAt: moment), at: moment))
        XCTAssertNil(pairing.candidate(from: sender(sentAt: moment.addingTimeInterval(601)), at: moment.addingTimeInterval(601)))
        XCTAssertTrue(pairing.isExpired(at: moment.addingTimeInterval(601)))
    }

    func testADeclinedAccountIsNotProposedAgain() {
        var pairing = ChannelPairing(startedAt: moment, window: 600)
        let first = sender(sentAt: moment)
        guard let proposed = pairing.candidate(from: first, at: moment) else { return XCTFail("debía proponerla") }
        pairing.decline(proposed)
        XCTAssertNil(pairing.candidate(from: first, at: moment))
        XCTAssertNotNil(pairing.candidate(from: sender(user: 9, sentAt: moment), at: moment))
    }
}
