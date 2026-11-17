import Foundation
import HirebarDomain
import XCTest

@testable import HirebarApplication

@MainActor
final class CommandFlowTests: XCTestCase {
    nonisolated static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-commands-\(UUID().uuidString)")
    var harness: EngineHarness!

    override static func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override static func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    override func setUp() async throws {
        harness = EngineHarness()
        harness.anchorOwner()
    }

    func testMessagesFromAnotherAccountAreIgnored() {
        harness.controller.handle(harness.message("estado", from: 99))
        XCTAssertTrue(harness.replies.isEmpty)
        XCTAssertTrue(harness.runner.requests.isEmpty)
    }

    func testStatusAnswersWithTheEngineState() {
        harness.controller.handle(harness.message("estado"))
        XCTAssertTrue(harness.replies.last?.contains("Cupos:") == true)
    }

    func testTheWeeklyReportCommandStartsTheAnalyst() {
        harness.controller.handle(harness.message("informe"))
        XCTAssertEqual(harness.batchMode(of: harness.runner.requests.first), .weeklyReport)
    }

    func testANoteIsKeptForTheWeeklyReport() {
        harness.controller.handle(harness.message("anota entrevista el jueves"))
        XCTAssertEqual(harness.replies.last, "Anotado para el informe del domingo.")
    }

    func testDiscardingMarksTheLatestPendingListAsDiscarded() {
        let proposal = Proposal(
            id: "li:1", action: .apply, target: .url("https://linkedin.com/jobs/view/1"), title: "Backend", source: "LinkedIn")
        let batch = Batch(mode: .jobs, items: [BatchItem(proposal)], status: .pending)
        harness.stores.batches.upsert(batch)
        harness.controller.handle(harness.message("no"))
        XCTAssertEqual(harness.stores.batches.find(id: batch.id)?.status, .discarded)
    }

    func testApprovingAListRunsItWithAnActingProfile() throws {
        harness.stores.agents.update(.jobs) { $0.practice = false }
        let proposal = Proposal(
            id: "li:9", action: .apply, target: .url("https://linkedin.com/jobs/view/9"), title: "Backend", source: "LinkedIn")
        let batch = Batch(mode: .jobs, items: [BatchItem(proposal)], status: .pending)
        harness.stores.batches.upsert(batch)
        harness.controller.handle(harness.message("si"))
        let request = try XCTUnwrap(harness.runner.requests.last)
        XCTAssertTrue(request.profile.canAct)
        XCTAssertEqual(request.runId, batch.id)
    }

    func testAnAchievementIsQueuedForTheProfileAgent() {
        harness.controller.handle(harness.message("logro bajé el costo de AWS 20% en Acme"))
        XCTAssertTrue(harness.stores.profile.changeRequests().contains("bajé el costo de AWS 20% en Acme"))
    }

    func testUnknownTextAnswersWithTheHelp() {
        harness.controller.handle(harness.message("zzz qqq"))
        XCTAssertEqual(harness.replies.last, Controller.help)
    }
}
