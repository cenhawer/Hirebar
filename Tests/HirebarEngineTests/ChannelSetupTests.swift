import Foundation
import HirebarCore
import HirebarDomain
import XCTest

@testable import HirebarEngine

final class ChannelSetupTests: XCTestCase {
    static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-channel-\(UUID().uuidString)")
    let moment = Date(timeIntervalSince1970: 1_800_000_000)
    var setup: ChannelSetup!

    override static func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override static func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    override func setUpWithError() throws {
        Config().save()
        let settings = try ChannelSettings.load(from: EngineProfileTests.repositoryRoot.appendingPathComponent("Resources/canal.json"))
        let moment = self.moment
        setup = ChannelSetup(settings: settings, now: { moment })
    }

    func sender(user: Int64, privateChat: Bool = true) -> ChannelSender {
        ChannelSender(userId: user, chatId: user, name: "Ana", username: "ana", isPrivateChat: privateChat, sentAt: moment)
    }

    func testConfirmingTheProposedAccountAnchorsTheBotToIt() {
        XCTAssertFalse(setup.offer(sender(user: 7)))
        setup.startPairing()
        XCTAssertTrue(setup.offer(sender(user: 7)))
        XCTAssertFalse(setup.offer(sender(user: 8)))
        setup.confirm(welcome: "hola")
        XCTAssertEqual(Config.load().channelOwner?.userId, 7)
        XCTAssertEqual(setup.admit(sender(user: 7)), .allowed)
        XCTAssertEqual(setup.admit(sender(user: 8)), .notOwner)
    }

    func testDecliningKeepsWaitingForTheRightAccount() {
        setup.startPairing()
        XCTAssertTrue(setup.offer(sender(user: 8)))
        setup.decline()
        XCTAssertFalse(setup.offer(sender(user: 8)))
        XCTAssertTrue(setup.offer(sender(user: 7)))
        XCTAssertNil(Config.load().channelOwner)
    }

    func testChangingAccountForgetsTheAnchoredOne() {
        setup.startPairing()
        _ = setup.offer(sender(user: 7))
        setup.confirm(welcome: "hola")
        setup.changeAccount()
        XCTAssertNil(Config.load().channelOwner)
        XCTAssertEqual(setup.admit(sender(user: 7)), .notOwner)
    }

    func testBundledChannelSettingsAreReadable() throws {
        let settings = try ChannelSettings.load(from: EngineProfileTests.repositoryRoot.appendingPathComponent("Resources/canal.json"))
        XCTAssertGreaterThan(settings.pairingWindow, 0)
        XCTAssertGreaterThan(settings.messagesPerMinute, 0)
    }
}
