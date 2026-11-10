import Foundation
import HirebarDomain
import XCTest

@testable import HirebarApplication

@MainActor
final class SchedulerTests: XCTestCase {
    nonisolated static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-scheduler-\(UUID().uuidString)")
    var harness: EngineHarness!
    var scheduler: Scheduler!
    let analyst = AgentKind.owner(of: .weeklyReport)

    override static func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override static func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    func start(at moment: Date) {
        harness = EngineHarness(at: moment)
        scheduler = Scheduler(stores: harness.stores, clock: harness.clock)
        scheduler.controller = harness.controller
        scheduler.start()
    }

    func testATaskRunsOnceInItsHourEvenIfTheClockTicksAgain() {
        start(at: EngineHarness.date(day: 10, hour: 10))
        harness.onlyEnable(analyst, tasks: [AgentTask(mode: .weeklyReport, hours: [10])])
        harness.clock.tick()
        harness.clock.tick()
        XCTAssertEqual(harness.runner.requests.count, 1)
        XCTAssertEqual(harness.batchMode(of: harness.runner.requests.first), .weeklyReport)
    }

    func testOutsideItsHourOrWithTheAgentOffNothingRuns() {
        start(at: EngineHarness.date(day: 10, hour: 13))
        harness.onlyEnable(analyst, tasks: [AgentTask(mode: .weeklyReport, hours: [10])])
        harness.clock.tick()
        harness.harnessDisable(analyst)
        harness.clock.moment = EngineHarness.date(day: 11, hour: 10)
        harness.clock.tick()
        XCTAssertTrue(harness.runner.requests.isEmpty)
    }

    func testAPortalScanWithoutOwnPortalsIsSkipped() throws {
        start(at: EngineHarness.date(day: 10, hour: 10))
        try harness.stores.portals.save([])
        harness.onlyEnable(.jobs, tasks: [AgentTask(mode: .portalScanJobs, hours: [10])])
        harness.clock.tick()
        XCTAssertTrue(harness.runner.requests.isEmpty)
    }

    func testWeeklyCleanupRunsOnceOnSundayEveningWhenTheEngineIsIdle() {
        start(at: EngineHarness.date(day: 15, hour: 20))
        harness.onlyEnable(analyst, tasks: [])
        harness.clock.tick()
        harness.clock.tick()
        XCTAssertEqual(harness.workspace.cleanUps, 1)
    }

    func testWeeklyCleanupWaitsUntilTheRunningTaskEnds() {
        start(at: EngineHarness.date(day: 15, hour: 20))
        harness.onlyEnable(analyst, tasks: [AgentTask(mode: .weeklyReport, hours: [20])])
        harness.clock.tick()
        XCTAssertEqual(harness.workspace.cleanUps, 0)
        harness.runner.finish(AIRunResult(code: 0, output: "Informe", authFailed: false, restoredFiles: []))
        harness.clock.tick()
        XCTAssertEqual(harness.workspace.cleanUps, 1)
    }

    func testTheNextRunIsTheNextTaskStart() throws {
        start(at: EngineHarness.date(day: 10, hour: 10))
        harness.onlyEnable(analyst, tasks: [AgentTask(mode: .weeklyReport, hours: [15])])
        let next = try XCTUnwrap(scheduler.nextRun(of: analyst))
        XCTAssertEqual(Calendar.current.component(.hour, from: next), 15)
        XCTAssertEqual(Calendar.current.component(.day, from: next), 10)
    }
}

extension EngineHarness {
    func harnessDisable(_ kind: AgentKind) {
        stores.agents.update(kind) { $0.enabled = false }
    }
}
