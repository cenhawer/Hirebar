import Foundation
import HirebarDomain
import XCTest

@testable import HirebarApplication

@MainActor
final class ControllerRunTests: XCTestCase {
    nonisolated static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-runs-\(UUID().uuidString)")
    var harness: EngineHarness!

    override static func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override static func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    override func setUp() async throws {
        harness = EngineHarness()
    }

    func result(code: Int32 = 0, authFailed: Bool = false) -> AIRunResult {
        AIRunResult(code: code, output: "salida", authFailed: authFailed, restoredFiles: [])
    }

    func testTasksWaitForTheRunningOneAndThenStart() {
        harness.controller.runScheduled(.weeklyReport, manual: true)
        harness.controller.runScheduled(.profileUpdate, manual: true)
        XCTAssertEqual(harness.runner.requests.count, 1)
        harness.runner.finish(result())
        XCTAssertEqual(harness.runner.requests.count, 2)
        XCTAssertEqual(harness.batchMode(of: harness.runner.requests.last), .profileUpdate)
    }

    func testTheSameTaskIsNotQueuedTwice() {
        harness.controller.runScheduled(.weeklyReport, manual: true)
        harness.controller.runScheduled(.weeklyReport, manual: true)
        XCTAssertEqual(harness.replies.last, "Eso ya está en curso.")
        harness.runner.finish(result())
        XCTAssertEqual(harness.runner.requests.count, 1)
    }

    func testAFailedRunIsMarkedAsFailed() throws {
        harness.controller.runScheduled(.weeklyReport, manual: true)
        let request = try XCTUnwrap(harness.runner.requests.first)
        harness.runner.finish(result(code: 2))
        XCTAssertEqual(harness.stores.batches.find(id: request.runId)?.status, .failed)
        XCTAssertTrue(harness.controller.isIdle)
    }

    func testAnExpiredSessionTellsHowToLogInAgain() {
        harness.controller.runScheduled(.weeklyReport, manual: true)
        harness.runner.finish(result(code: 1, authFailed: true))
        XCTAssertTrue(harness.replies.contains { $0.contains("se venció") })
    }

    func testARunLongerThanTheLimitIsStopped() throws {
        harness.controller.runScheduled(.weeklyReport, manual: true)
        let run = try XCTUnwrap(harness.runner.runs.first)
        harness.clock.advance(by: Controller.maxRunSeconds + 1)
        XCTAssertFalse(run.isRunning)
    }
}
