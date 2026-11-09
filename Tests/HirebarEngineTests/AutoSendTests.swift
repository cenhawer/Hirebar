import Foundation
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import XCTest

@testable import HirebarEngine

final class AutoSendTests: XCTestCase {
    var controller: Controller!
    static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-auto-\(UUID().uuidString)")
    var replies: [String] = []
    var questions: [(String, [[(String, String)]])] = []

    override static func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override static func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    override func setUp() {
        controller = Controller(telegram: Telegram(secrets: NoTestSecrets()), stores: .files)
        for kind in AutoSend.agents { AgentStore.update(kind) { $0.autoApprove = false } }
        replies = []
        questions = []
        controller.replies = { [weak self] text in self?.replies.append(text) }
        controller.questions = { [weak self] text, buttons in self?.questions.append((text, buttons)) }
    }

    override func tearDown() {
    }

    func testAskingFromTelegramDoesNotTurnItOnUntilThePersonConfirms() {
        controller.askToTurnOnAutoSend([.jobs])
        XCTAssertFalse(AgentStore.load(.jobs).autoApprove)
        XCTAssertEqual(questions.first?.1.first?.first?.1, "autoon:empleo")
        XCTAssertTrue(questions.first?.0.contains("Nunca salen solos") ?? false)
        controller.confirmAutoSend("empleo")
        XCTAssertTrue(AgentStore.load(.jobs).autoApprove)
    }

    func testOnlyAgentsWithAutomaticSendingCanBeTurnedOn() {
        controller.confirmAutoSend("contenido,perfil")
        XCTAssertFalse(AgentStore.load(.content).autoApprove)
        XCTAssertTrue(replies.isEmpty)
    }

    func testSettingsDetectWhichAgentsWereJustTurnedOn() {
        let saved = AgentKind.allCases.map(AgentStore.load)
        var edited = saved
        if let index = edited.firstIndex(where: { $0.id == .freelance }) { edited[index].autoApprove = true }
        if let index = edited.firstIndex(where: { $0.id == .content }) { edited[index].autoApprove = true }
        XCTAssertEqual(AutoSend.newlyEnabled(saved: saved, edited: edited), [.freelance])
    }

    func testTurningOffNeedsNoConfirmation() {
        AutoSend.turnOn(.clients, from: "test", agents: FileAgentRepository())
        AutoSend.turnOff(.clients, from: "test", agents: FileAgentRepository())
        XCTAssertFalse(AgentStore.load(.clients).autoApprove)
    }
}
