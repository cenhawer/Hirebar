import Foundation
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import XCTest

@testable import HirebarEngine

final class ChannelSetupTests: XCTestCase {
    static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-channel-\(UUID().uuidString)")
    let started = Date(timeIntervalSince1970: 1_800_000_000)
    var moment = Date(timeIntervalSince1970: 1_800_000_000)
    var sent: [(String, Int64)] = []
    var tokenRejected = false
    var tokenSaved = true
    var setup: ChannelSetup!

    override static func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override static func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    var settings: ChannelSettings {
        get throws { try ChannelSettings.load(from: EngineProfileTests.repositoryRoot.appendingPathComponent("Resources/canal.json")) }
    }

    func makeSetup(settings: ChannelSettings?) -> ChannelSetup {
        let telegram = ChannelTelegram(
            isConfigured: { true },
            tokenRejected: { [unowned self] in self.tokenRejected },
            send: { [unowned self] text, chat in self.sent.append((text, chat)) },
            saveToken: { [unowned self] _ in self.tokenSaved },
            removeToken: { [unowned self] in self.tokenSaved },
            start: {}
        )
        return ChannelSetup(settings: settings, telegram: telegram, now: { [unowned self] in self.moment })
    }

    override func setUpWithError() throws {
        var config = Config()
        config.botUsername = "hirebar_bot"
        config.save()
        moment = started
        sent = []
        tokenRejected = false
        tokenSaved = true
        setup = makeSetup(settings: try settings)
    }

    func sender(user: Int64, viaButton: Bool = false) -> ChannelSender {
        ChannelSender(
            userId: user, chatId: user, name: "Ana", username: "ana", isPrivateChat: true, sentAt: started, viaButton: viaButton)
    }

    func testConfirmingTheProposedAccountAnchorsTheBotToItAndWelcomesIt() {
        XCTAssertEqual(setup.state, .unlinked(bot: "hirebar_bot"))
        XCTAssertFalse(setup.offer(sender(user: 7), text: "hola"))
        setup.startPairing()
        XCTAssertEqual(setup.state, .waitingForHello(bot: "hirebar_bot"))
        XCTAssertTrue(setup.offer(sender(user: 7), text: "hola"))
        guard case .confirming(let candidate, _) = setup.state else { return XCTFail("debía pedir confirmación") }
        XCTAssertEqual(candidate.text, "hola")
        setup.confirm(welcome: "bienvenida")
        XCTAssertEqual(Config.load().channelOwner?.userId, 7)
        XCTAssertEqual(sent.first?.1, 7)
        XCTAssertEqual(setup.admit(sender(user: 7)), .allowed)
        XCTAssertEqual(setup.admit(sender(user: 8)), .notOwner)
        XCTAssertEqual(setup.admit(sender(user: 8, viaButton: true)), .notOwner)
    }

    func testDecliningShowsTheNextAccountThatWrote() {
        setup.startPairing()
        XCTAssertTrue(setup.offer(sender(user: 8), text: "hola"))
        XCTAssertTrue(setup.offer(sender(user: 7), text: "hola, soy yo"))
        setup.decline()
        guard case .confirming(let candidate, _) = setup.state else { return XCTFail("debía mostrar el siguiente") }
        XCTAssertEqual(candidate.owner.userId, 7)
        XCTAssertNil(Config.load().channelOwner)
    }

    func testButtonsDoNotCountAsTheHello() {
        setup.startPairing()
        XCTAssertFalse(setup.offer(sender(user: 7, viaButton: true), text: "si:b1"))
        XCTAssertEqual(setup.state, .waitingForHello(bot: "hirebar_bot"))
    }

    func testPairingExpiresAfterItsWindow() throws {
        setup.startPairing()
        moment = started.addingTimeInterval(try settings.pairingWindow + 1)
        XCTAssertEqual(setup.state, .expired(bot: "hirebar_bot"))
        XCTAssertFalse(setup.offer(sender(user: 7), text: "hola"))
    }

    func testChangingAccountForgetsTheAnchoredOneAndCancelStopsWaiting() {
        setup.startPairing()
        _ = setup.offer(sender(user: 7), text: "hola")
        setup.confirm(welcome: "hola")
        setup.changeAccount()
        XCTAssertNil(Config.load().channelOwner)
        XCTAssertEqual(setup.admit(sender(user: 7)), .notOwner)
        setup.cancelPairing()
        XCTAssertEqual(setup.state, .unlinked(bot: "hirebar_bot"))
    }

    func testRejectedTokenAndMissingSettingsAreShown() {
        tokenRejected = true
        XCTAssertEqual(setup.state, .tokenRejected)
        let broken = makeSetup(settings: nil)
        XCTAssertEqual(broken.state, .misconfigured)
        XCTAssertEqual(broken.admit(sender(user: 7)), .notOwner)
    }

    func testRemovingTheBotKeepsTheConfigurationWhenTheKeychainFails() {
        setup.startPairing()
        _ = setup.offer(sender(user: 7), text: "hola")
        setup.confirm(welcome: "hola")
        tokenSaved = false
        XCTAssertEqual(setup.removeBot(), .keychainFailed)
        XCTAssertEqual(Config.load().channelOwner?.userId, 7)
        tokenSaved = true
        XCTAssertEqual(setup.removeBot(), .done)
        XCTAssertNil(Config.load().channelOwner)
    }

    func testMessagesFromAnotherAccountNeverReachTheCommands() {
        var config = Config.load()
        config.channelOwner = ChannelOwner(userId: 7, chatId: 7, name: "Ana")
        config.save()
        let controller = Controller(telegram: Telegram(secrets: NoTestSecrets()))
        controller.channel = setup
        let chat: [String: Any] = ["id": 7, "type": "private"]
        let button: [String: Any] = [
            "id": "c1", "data": "si:b1", "from": ["id": 99, "first_name": "Ana"], "message": ["message_id": 1, "chat": chat],
        ]
        let text: [String: Any] = ["message_id": 2, "date": 1, "text": "estado", "from": ["id": 7, "first_name": "Ana"], "chat": chat]
        guard let stranger = Telegram.parse(["callback_query": button]), let owner = Telegram.parse(["message": text]) else {
            return XCTFail("debía leer los updates")
        }
        XCTAssertFalse(controller.admits(stranger))
        XCTAssertTrue(controller.admits(owner))
    }

    func testBundledChannelSettingsAreReadable() throws {
        XCTAssertGreaterThan(try settings.pairingWindow, 0)
        XCTAssertGreaterThan(try settings.messagesPerMinute, 0)
    }
}
