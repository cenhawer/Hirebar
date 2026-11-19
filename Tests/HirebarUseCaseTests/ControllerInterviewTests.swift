import Foundation
import HirebarDomain
import XCTest

@testable import HirebarApplication

@MainActor
final class ControllerInterviewTests: XCTestCase {
    var home: URL!
    var harness: EngineHarness!

    override func setUp() async throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-interview-\(UUID().uuidString)")
        setenv("HIREBAR_HOME", home.path, 1)
        harness = EngineHarness()
        harness.anchorOwner()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: home)
    }

    func sentApplication(id: String, url: String) throws {
        let record = ActionRecord(itemId: id, action: .apply, target: .url(url), sentText: nil, outcome: .done, reason: nil, at: Date())
        let verification = ExecutionVerification(batch: "e-\(id)", unverifiedReason: nil, verdicts: [.authorized(record)])
        try harness.stores.executionState.save(verification, agent: AgentID(rawValue: AgentKind.jobs.rawValue))
    }

    func testNoApplicationsRepliesThatNoneExist() {
        harness.controller.runInterviewPrep("")
        XCTAssertEqual(harness.replies.last, "No tienes postulaciones enviadas todavía.")
        XCTAssertEqual(harness.runner.requests.count, 0)
    }

    func testOneApplicationStartsThePrepWithoutAskingWhich() throws {
        try sentApplication(id: "a1", url: "https://ejemplo.com/vacante-backend")
        harness.controller.runInterviewPrep("")
        XCTAssertEqual(harness.runner.requests.count, 1)
        XCTAssertTrue(harness.replies.last?.contains("Preparando tu entrevista") ?? false)
    }

    func testSeveralApplicationsAskWhichOneWithoutStartingAnything() throws {
        try sentApplication(id: "a1", url: "https://ejemplo.com/vacante-backend")
        try sentApplication(id: "a2", url: "https://ejemplo.com/vacante-frontend")
        harness.controller.runInterviewPrep("")
        XCTAssertEqual(harness.runner.requests.count, 0)
        XCTAssertTrue(harness.replies.last?.contains("vacante-backend") ?? false)
        XCTAssertTrue(harness.replies.last?.contains("vacante-frontend") ?? false)
    }

    func testQueryNarrowsDownToOneMatch() throws {
        try sentApplication(id: "a1", url: "https://ejemplo.com/vacante-backend")
        try sentApplication(id: "a2", url: "https://ejemplo.com/vacante-frontend")
        harness.controller.runInterviewPrep("backend")
        XCTAssertEqual(harness.runner.requests.count, 1)
    }

    func testTwoDifferentApplicationsWithTheSameDisplayTextAreNotCollapsed() throws {
        try sentApplication(id: "a1", url: "https://ejemplo.com/aplica")
        try sentApplication(id: "a2", url: "https://ejemplo.com/aplica")
        harness.controller.runInterviewPrep("")
        XCTAssertEqual(harness.runner.requests.count, 0)
        XCTAssertTrue(harness.replies.last?.contains("Tienes varias postulaciones") ?? false)
    }

    func testNoMatchForTheGivenQueryDoesNotInventAnything() throws {
        try sentApplication(id: "a1", url: "https://ejemplo.com/vacante-backend")
        harness.controller.runInterviewPrep("devops en marte")
        XCTAssertEqual(harness.runner.requests.count, 0)
        XCTAssertEqual(harness.replies.last, "No encontré ninguna postulación con \"devops en marte\".")
    }

    func testCompletingThePrepRepliesTheSummaryAndTheFilePath() throws {
        try sentApplication(id: "a1", url: "https://ejemplo.com/vacante-backend")
        harness.controller.runInterviewPrep("")
        let request = try XCTUnwrap(harness.runner.requests.first)
        harness.runner.finish(AIRunResult(code: 0, output: "Vacante de Backend, 6 preguntas.", authFailed: false, restoredFiles: []))
        XCTAssertTrue(harness.replies.contains("Vacante de Backend, 6 preguntas."))
        XCTAssertTrue(harness.replies.last?.contains("entrevistas/\(request.runId).md") ?? false)
    }
}
