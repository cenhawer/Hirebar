import Foundation
import HirebarDomain
import XCTest

@testable import HirebarApplication

@MainActor
final class PendingInboxTests: XCTestCase {
    nonisolated static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-inbox-\(UUID().uuidString)")
    let account = ContentAccount(id: "empresa")
    var harness: EngineHarness!

    override static func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override static func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    override func setUp() async throws {
        try? FileManager.default.removeItem(at: Self.home)
        harness = EngineHarness()
        harness.stores.agents.update(.jobs) { $0.practice = false }
    }

    func pendingJobs(_ count: Int) -> Batch {
        let items = (1...count).map { number in
            BatchItem(
                Proposal(
                    id: "li:\(number)", action: .apply, target: .url("https://linkedin.com/jobs/view/\(number)"),
                    title: "Vacante \(number)",
                    source: "LinkedIn"))
        }
        let batch = Batch(mode: .jobs, items: items, status: .pending)
        harness.stores.batches.upsert(batch)
        return batch
    }

    func testOnlyPendingListsAppearNumberedWithTheirTarget() throws {
        let pending = pendingJobs(2)
        var done = Batch(mode: .freelance, items: pending.items, status: .done)
        done.id = "otra"
        harness.stores.batches.upsert(done)
        let lists = harness.controller.pendingLists()
        XCTAssertEqual(lists.map(\.id), [pending.id])
        let list = try XCTUnwrap(lists.first)
        XCTAssertEqual(list.items.map(\.number), [1, 2])
        XCTAssertEqual(list.items.first?.target, "https://linkedin.com/jobs/view/1")
        XCTAssertEqual(list.title, Mode.jobs.title)
    }

    func testChoosingNothingAllOrSomeGivesThePicksTelegramUses() throws {
        let list = try XCTUnwrap(PendingInbox.lists(from: [pendingJobs(3)]).first)
        var selection = InboxSelection()
        XCTAssertNil(selection.picks(for: list))
        selection.toggle(3, in: list.id)
        selection.toggle(1, in: list.id)
        XCTAssertEqual(selection.picks(for: list), [1, 3])
        selection.toggle(2, in: list.id)
        XCTAssertEqual(selection.picks(for: list), [])
        selection.toggle(2, in: list.id)
        XCTAssertEqual(selection.count(in: list.id), 2)
        selection.clear(list.id)
        XCTAssertFalse(selection.isSelected(1, in: list.id))
    }

    func testApprovingChosenItemsRunsOnlyThoseWithTheActingProfile() throws {
        let batch = pendingJobs(3)
        harness.controller.approveList(batch.id, picks: [1, 3])
        let request = try XCTUnwrap(harness.runner.requests.last)
        XCTAssertTrue(request.profile.canAct)
        XCTAssertEqual(harness.stores.batches.find(id: batch.id)?.items.map(\.id), ["li:1", "li:3"])
        XCTAssertTrue(harness.controller.pendingLists().isEmpty)
    }

    func testDiscardingFromTheInboxMarksTheListDiscarded() {
        let batch = pendingJobs(1)
        harness.controller.discardPendingList(batch.id)
        XCTAssertEqual(harness.stores.batches.find(id: batch.id)?.status, .discarded)
    }

    func writeDraft() throws {
        try harness.stores.contentAccounts.save([account])
        try FileManager.default.createDirectory(at: account.slides, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: account.videoFolder, withIntermediateDirectories: true)
        try "Una publicación lista para revisar con texto suficiente".write(to: account.draft, atomically: true, encoding: .utf8)
        for name in ["2.png", "1.png", "1.html"] { try Data().write(to: account.slides.appendingPathComponent(name)) }
        try Data().write(to: account.previewVideo)
    }

    func testAPendingPostShowsItsTextSlidesAndVideo() throws {
        try writeDraft()
        let draft = try XCTUnwrap(harness.controller.pendingDrafts().first)
        XCTAssertEqual(draft.id, "empresa")
        XCTAssertTrue(draft.text.hasPrefix("Una publicación"))
        XCTAssertEqual(draft.slides.map(\.lastPathComponent), ["1.png", "2.png"])
        XCTAssertEqual(draft.video?.lastPathComponent, "vista-previa.mp4")
    }

    func testPublishingAndSkippingAPostUseTheSameFlowAsTelegram() throws {
        try writeDraft()
        harness.controller.publishDraft(of: account.id)
        XCTAssertEqual(harness.batchMode(of: harness.runner.requests.last), .linkedInPublish)
        harness.controller.skipDraft(of: account.id)
        XCTAssertTrue(harness.controller.pendingDrafts().isEmpty)
        XCTAssertTrue(harness.replies.last?.contains("no se publica") == true)
    }
}
