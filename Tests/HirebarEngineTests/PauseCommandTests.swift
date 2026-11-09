import Foundation
import HirebarApplication
import HirebarCore
import HirebarDomain
import XCTest

@testable import HirebarEngine

final class SilentAlerts: ExecutionAlerts {
    func executionNeedsReview(agent: AgentID, verification: ExecutionVerification, pauseSaved: Bool) {}
}

final class PauseCommandTests: XCTestCase {
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
        store = FileExecutionStateStore(
            stateFolder: Self.home.appendingPathComponent("estado-\(UUID().uuidString)"),
            runsFolder: Self.home.appendingPathComponent("ejecuciones"))
        Controller.shared.executionGuard = ExecutionGuard(store: store, alerts: SilentAlerts())
        Controller.shared.unsavedPauses = [:]
        replies = []
        Controller.shared.replies = { [weak self] text in self?.replies.append(text) }
    }

    override func tearDown() {
        Controller.shared.replies = Notifier.tell
    }

    func testPauseIsVisibleAndOnlyLiftedOnce() throws {
        try store.pause(AgentPause(agent: jobs, batch: "b1", reason: "notApproved", since: Date()))
        XCTAssertEqual(Controller.shared.pauseReason(of: .jobs), "lista b1 (notApproved)")
        XCTAssertEqual(Controller.shared.pauseReasons(), [.jobs: "lista b1 (notApproved)"])
        XCTAssertNil(Controller.shared.pauseReason(of: .freelance))
        XCTAssertTrue(Controller.shared.resumeAgent(.jobs))
        XCTAssertNil(Controller.shared.pauseReason(of: .jobs))
        XCTAssertFalse(Controller.shared.resumeAgent(.jobs))
    }

    func testResumeButtonLiftsThePauseAndSaysWhatStillWaits() throws {
        try store.pause(AgentPause(agent: jobs, batch: "b1", reason: "notApproved", since: Date()))
        Controller.shared.resumeAgent(named: "empleo")
        XCTAssertNil(store.pauses().first)
        XCTAssertTrue(replies.last?.contains("reanudado") ?? false)
        XCTAssertFalse(replies.last?.contains("se vuelven a ejecutar") ?? true)
    }

    func testKeepButtonLeavesThePauseAndExplainsHowToResume() throws {
        try store.pause(AgentPause(agent: jobs, batch: "b1", reason: "notApproved", since: Date()))
        Controller.shared.keepPaused(named: "empleo")
        XCTAssertEqual(store.pauses().map(\.batch), ["b1"])
        XCTAssertTrue(replies.last?.contains("reanudar empleo") ?? false)
    }

    func testPauseThatCouldNotBeSavedStillBlocksTheAgentUntilResumed() {
        let pause = AgentPause(agent: jobs, batch: "b2", reason: "logMissing", since: Date())
        Controller.shared.unsavedPauses[jobs] = pause
        XCTAssertEqual(Controller.shared.activePause(of: jobs), pause)
        XCTAssertTrue(Controller.shared.resumeAgent(.jobs))
        XCTAssertNil(Controller.shared.activePause(of: jobs))
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
