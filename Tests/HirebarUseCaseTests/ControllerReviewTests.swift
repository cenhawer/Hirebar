import Foundation
import HirebarDomain
import XCTest

@testable import HirebarApplication

@MainActor
final class ControllerReviewTests: XCTestCase {
    nonisolated static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-review-\(UUID().uuidString)")
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

    func proposalsBlock(id: String, title: String) -> String {
        """
        HIREBAR_PROPOSALS_BEGIN
        {"schemaVersion": 1, "proposals": [
          {"id": "\(id)", "action": "apply", "target": {"url": "https://ejemplo.com/\(id)"},
           "title": "\(title)", "source": "LinkedIn", "fit": "ENCAJA"}
        ]}
        HIREBAR_PROPOSALS_END
        """
    }

    func pendingJobsBatch(containing proposalId: String) -> Batch? {
        harness.stores.batches.load().last { $0.mode == .jobs && $0.status == .pending && $0.items.contains { $0.id == proposalId } }
    }

    func finishDraft(id: String, title: String) {
        harness.runner.finish(AIRunResult(code: 0, output: proposalsBlock(id: id, title: title), authFailed: false, restoredFiles: []))
    }

    func testReviewEnabledCorrectsTheDraftBeforeOffering() throws {
        harness.stores.agents.update(.jobs) { $0.reviewEnabled = true }
        harness.controller.runScheduled(.social, manual: true)
        finishDraft(id: "post:corrects", title: "Backend")
        XCTAssertEqual(harness.runner.requests.count, 2)
        XCTAssertNil(pendingJobsBatch(containing: "post:corrects"))

        finishDraft(id: "post:corrects", title: "Backend Senior")
        let batch = try XCTUnwrap(pendingJobsBatch(containing: "post:corrects"))
        XCTAssertEqual(batch.items.first?.title, "Backend Senior")
        let draft = try XCTUnwrap(harness.stores.executionState.reviewedDraft(batch: batch.id))
        XCTAssertEqual(draft.outcome, .corrected)
        XCTAssertEqual(draft.original.first?.title, "Backend")
        XCTAssertEqual(draft.final.first?.title, "Backend Senior")
    }

    func testReviewWithNoChangesOffersTheOriginalUnchanged() throws {
        harness.stores.agents.update(.jobs) { $0.reviewEnabled = true }
        harness.controller.runScheduled(.social, manual: true)
        finishDraft(id: "post:nochange", title: "Backend")
        finishDraft(id: "post:nochange", title: "Backend")
        let batch = try XCTUnwrap(pendingJobsBatch(containing: "post:nochange"))
        let draft = try XCTUnwrap(harness.stores.executionState.reviewedDraft(batch: batch.id))
        XCTAssertEqual(draft.outcome, .approvedAsIs)
    }

    func testReviewTimeoutFallsBackToTheOriginalDraft() throws {
        harness.stores.agents.update(.jobs) { $0.reviewEnabled = true }
        harness.controller.runScheduled(.social, manual: true)
        finishDraft(id: "post:timeout", title: "Backend")
        XCTAssertNil(pendingJobsBatch(containing: "post:timeout"))

        harness.clock.advance(by: harness.controller.policy.corridas.reviewTimeout + 1)
        let batch = try XCTUnwrap(pendingJobsBatch(containing: "post:timeout"))
        XCTAssertEqual(batch.items.first?.title, "Backend")
        let draft = try XCTUnwrap(harness.stores.executionState.reviewedDraft(batch: batch.id))
        XCTAssertEqual(draft.outcome, .skippedTimeout)
        XCTAssertTrue(harness.controller.isIdle)
    }

    func testReviewDisabledMeansOnlyOneAIInvocation() throws {
        harness.controller.runScheduled(.social, manual: true)
        finishDraft(id: "post:disabled", title: "Backend")
        XCTAssertEqual(harness.runner.requests.count, 1)
        let batch = try XCTUnwrap(pendingJobsBatch(containing: "post:disabled"))
        XCTAssertNil(harness.stores.executionState.reviewedDraft(batch: batch.id))
    }
}
