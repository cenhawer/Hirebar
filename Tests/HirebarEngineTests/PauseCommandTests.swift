import Foundation
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import XCTest

@testable import HirebarEngine

struct NoTestSecrets: SecretStore {
    func secret(for account: String) -> String? { nil }
    func save(_ secret: String, for account: String) -> Bool { false }
    func delete(_ account: String) -> Bool { false }
}

final class SilentAlerts: ExecutionAlerts {
    func executionNeedsReview(agent: AgentID, verification: ExecutionVerification, pauseSaved: Bool) {}
}

final class PauseCommandTests: XCTestCase {
    var controller: Controller!
    static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-pause-\(UUID().uuidString)")

    var store: FileExecutionStateStore!
    var replies: [String] = []
    let jobs = AgentID(rawValue: "empleo")

    override static func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override static func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    override func setUp() {
        controller = Controller(telegram: Telegram(secrets: NoTestSecrets()), stores: .files)
        store = FileExecutionStateStore(
            stateFolder: Self.home.appendingPathComponent("estado-\(UUID().uuidString)"),
            runsFolder: Self.home.appendingPathComponent("ejecuciones"))
        controller.executionGuard = ExecutionGuard(store: store, alerts: SilentAlerts())
        controller.unsavedPauses = [:]
        replies = []
        controller.replies = { [weak self] text in self?.replies.append(text) }
    }

    override func tearDown() {
    }

    func testPauseIsVisibleAndOnlyLiftedOnce() throws {
        try store.pause(AgentPause(agent: jobs, batch: "b1", reason: "notApproved", since: Date()))
        XCTAssertEqual(controller.pauseReason(of: .jobs), "lista b1 (notApproved)")
        XCTAssertEqual(controller.pauseReasons(), [.jobs: "lista b1 (notApproved)"])
        XCTAssertNil(controller.pauseReason(of: .freelance))
        XCTAssertTrue(controller.resumeAgent(.jobs))
        XCTAssertNil(controller.pauseReason(of: .jobs))
        XCTAssertFalse(controller.resumeAgent(.jobs))
    }

    func testResumeButtonLiftsThePauseAndSaysWhatStillWaits() throws {
        try store.pause(AgentPause(agent: jobs, batch: "b1", reason: "notApproved", since: Date()))
        controller.resumeAgent(named: "empleo")
        XCTAssertNil(store.pauses().first)
        XCTAssertTrue(replies.last?.contains("reanudado") ?? false)
        XCTAssertFalse(replies.last?.contains("se vuelven a ejecutar") ?? true)
    }

    func testKeepButtonLeavesThePauseAndExplainsHowToResume() throws {
        try store.pause(AgentPause(agent: jobs, batch: "b1", reason: "notApproved", since: Date()))
        controller.keepPaused(named: "empleo")
        XCTAssertEqual(store.pauses().map(\.batch), ["b1"])
        XCTAssertTrue(replies.last?.contains("reanudar empleo") ?? false)
    }

    func testPauseThatCouldNotBeSavedStillBlocksTheAgentUntilResumed() {
        let pause = AgentPause(agent: jobs, batch: "b2", reason: "logMissing", since: Date())
        controller.unsavedPauses[jobs] = pause
        XCTAssertEqual(controller.activePause(of: jobs), pause)
        XCTAssertTrue(controller.resumeAgent(.jobs))
        XCTAssertNil(controller.activePause(of: jobs))
    }

    func testReviewMessageExplainsEachViolationAndHowToResume() {
        let record = ActionRecord(
            itemId: "n1", action: .sendEmail, target: .email("otro@ejemplo.com"), sentText: "x", outcome: .done, at: Date())
        let verification = ExecutionVerification(batch: "b9", unverifiedReason: nil, verdicts: [.unauthorized(record, .targetMismatch)])
        let message = TelegramExecutionAlerts.message(agentName: "Ventas", alias: "clientes", verification: verification, pauseSaved: true)
        XCTAssertTrue(message.contains("b9"))
        XCTAssertTrue(message.contains("otro@ejemplo.com"))
        XCTAssertTrue(message.contains("lo mandó a otro destino"))
        XCTAssertTrue(message.contains("reanudar clientes"))
        XCTAssertFalse(message.contains("No pude guardar"))
    }

    func testMissingLogAndUnsavedPauseAreExplained() {
        let verification = ExecutionVerification(batch: "b9", unverifiedReason: .logMissing, verdicts: [])
        let message = TelegramExecutionAlerts.message(agentName: "Empleo", alias: "empleo", verification: verification, pauseSaved: false)
        XCTAssertTrue(message.contains("no dejó el registro"))
        XCTAssertTrue(message.contains("No pude guardar la pausa"))
    }
}
