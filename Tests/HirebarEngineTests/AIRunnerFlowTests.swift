import Foundation
import HirebarApplication
import HirebarDomain
import HirebarStorage
import HirebarTelegram
import XCTest

@testable import HirebarEngine

final class AIRunnerFlowTests: XCTestCase {
    static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-runner-\(UUID().uuidString)")
    var runner: TestAIRunner!
    var controller: Controller!
    var replies: [String] = []

    override static func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override static func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    override func setUp() {
        runner = TestAIRunner()
        controller = Controller.forTests(aiRunner: runner)
        replies = []
        controller.replies = { [weak self] text in self?.replies.append(text) }
    }

    func testAReadingTaskRunsWithAReadOnlyProfileAndFreesTheEngineWhenItEnds() throws {
        controller.runScheduled(.weeklyReport, manual: true)
        let request = try XCTUnwrap(runner.requests.first)
        XCTAssertFalse(request.profile.canAct)
        XCTAssertFalse(controller.isIdle)
        runner.finish(AIRunResult(code: 0, output: "Informe listo", authFailed: false, restoredFiles: []))
        XCTAssertTrue(controller.isIdle)
        XCTAssertEqual(controller.stores.batches.find(id: request.runId)?.status, .done)
    }

    func testAnUnavailableEngineFailsTheBatchAndTellsThePersonWhy() throws {
        runner.failure = .unavailable(message: "Falta la IA", status: "falta instalar")
        controller.runScheduled(.weeklyReport, manual: true)
        let request = try XCTUnwrap(runner.requests.first)
        XCTAssertTrue(replies.contains("Falta la IA"))
        XCTAssertEqual(controller.status, "falta instalar")
        XCTAssertEqual(controller.stores.batches.find(id: request.runId)?.status, .failed)
        XCTAssertTrue(controller.isIdle)
    }
}
