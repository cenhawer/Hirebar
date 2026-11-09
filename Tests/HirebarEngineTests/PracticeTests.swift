import Foundation
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import XCTest

@testable import HirebarEngine

final class PracticeTests: XCTestCase {
    var controller: Controller!
    static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-practice-\(UUID().uuidString)")
    var store: FileExecutionStateStore!
    var replies: [String] = []

    override static func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override static func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    override func setUp() {
        controller = Controller.forTests()
        store = FileExecutionStateStore(
            stateFolder: Self.home.appendingPathComponent("estado-\(UUID().uuidString)"), runsFolder: Paths.runs)
        controller.executionGuard = ExecutionGuard(store: store, alerts: SilentAlerts())
        replies = []
        controller.replies = { [weak self] text in self?.replies.append(text) }
        AgentStore.update(.jobs) { $0.practice = false }
    }

    override func tearDown() {
        AgentStore.update(.jobs) { $0.practice = false }
    }

    var vacancy: Proposal {
        Proposal(id: "li:1", action: .apply, target: .url("https://linkedin.com/jobs/view/1"), title: "Backend", source: "LinkedIn")
    }

    func testAnAgentInPracticeSendsNothingAndRecordsWhatItWouldHaveDone() throws {
        Practice.set(.jobs, on: true, from: "test", agents: FileAgentRepository())
        let batch = Batch(mode: .jobs, items: [BatchItem(vacancy)], status: .running)
        _ = try controller.executionGuard.approve(
            [vacancy], batch: batch.id, approvedBy: .person, agent: AgentID(rawValue: "empleo"), dailyLimit: 1)
        XCTAssertTrue(controller.simulateIfPracticing(batch))
        XCTAssertEqual(PracticeLog.read(batch: batch.id)?.wouldSend, [vacancy])
        XCTAssertTrue(store.approvedItems(batch: batch.id).isEmpty)
        XCTAssertEqual(controller.executionGuard.remainingQuota(of: AgentID(rawValue: "empleo"), dailyLimit: 1), 1)
        XCTAssertTrue(replies.last?.contains("no envió nada") ?? false)
        XCTAssertEqual(BatchStore.find(id: batch.id)?.status, .done)
    }

    func testAnAgentOutOfPracticeRunsForReal() {
        let batch = Batch(mode: .jobs, items: [BatchItem(vacancy)], status: .running)
        XCTAssertFalse(controller.simulateIfPracticing(batch))
        XCTAssertNil(PracticeLog.read(batch: batch.id))
    }

    func testTheSummaryListsWhatWouldHaveBeenSent() {
        let summary = Controller.practiceSummary(agentName: "Empleo", items: [vacancy])
        XCTAssertTrue(summary.contains("Habría hecho 1"))
        XCTAssertTrue(summary.contains("linkedin.com/jobs/view/1"))
    }
}
