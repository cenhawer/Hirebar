import Foundation
import HirebarApplication
import HirebarCore
import HirebarDomain
import XCTest

@testable import HirebarEngine

final class PauseCommandTests: XCTestCase {
    static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-pause-\(UUID().uuidString)")

    override class func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override class func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    func testPauseIsVisibleAndOnlyLiftedOnce() throws {
        let store = FileExecutionStateStore(stateFolder: Self.home.appendingPathComponent("estado"))
        try store.pause(AgentPause(agent: AgentID(rawValue: "empleo"), batch: "b1", reason: "notApproved", since: Date()))
        XCTAssertEqual(Controller.shared.pauseReason(of: .jobs), "lista b1 (notApproved)")
        XCTAssertNil(Controller.shared.pauseReason(of: .freelance))
        XCTAssertTrue(Controller.shared.resumeAgent(.jobs))
        XCTAssertNil(Controller.shared.pauseReason(of: .jobs))
        XCTAssertFalse(Controller.shared.resumeAgent(.jobs))
    }

    func testReviewMessageExplainsEachViolationAndHowToResume() {
        let record = ActionRecord(
            itemId: "n1", action: .sendEmail, target: .email("otro@ejemplo.com"), sentText: "x", outcome: .done, at: Date())
        let verification = ExecutionVerification(batch: "b9", unverifiedReason: nil, verdicts: [.unauthorized(record, .targetMismatch)])
        let message = TelegramExecutionAlerts.message(agentName: "Clientes", verification: verification)
        XCTAssertTrue(message.contains("b9"))
        XCTAssertTrue(message.contains("otro@ejemplo.com"))
        XCTAssertTrue(message.contains("lo mandó a otro destino"))
        XCTAssertTrue(message.contains("reanudar clientes"))
    }

    func testMissingLogIsExplained() {
        let verification = ExecutionVerification(batch: "b9", unverifiedReason: .logMissing, verdicts: [])
        XCTAssertTrue(TelegramExecutionAlerts.message(agentName: "Empleo", verification: verification).contains("no dejó el registro"))
    }
}
