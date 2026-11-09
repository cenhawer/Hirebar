import HirebarDomain
import XCTest

@testable import HirebarCore

final class FileExecutionStateStoreTests: XCTestCase {
    var folder: URL!
    var store: FileExecutionStateStore!
    let moment = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let moment = self.moment
        store = FileExecutionStateStore(
            stateFolder: folder.appendingPathComponent("estado"),
            runsFolder: folder.appendingPathComponent("workspace/ejecuciones"),
            now: { moment }
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    var item: ApprovedItem {
        ApprovedItem(
            proposal: Proposal(id: "li:1", action: .apply, target: .url("https://linkedin.com/jobs/view/1"), title: "t", source: "s"),
            batch: "b1",
            approvedAt: moment,
            approvedBy: .person
        )
    }

    func testApprovedItemsRoundTripOutsideTheWorkspace() throws {
        try store.saveApproved([item], batch: "b1", agent: AgentID(rawValue: "empleo"))
        XCTAssertEqual(store.approvedItems(batch: "b1"), [item])
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("estado/aprobados/b1.json").path))
        XCTAssertEqual(store.approvedItems(batch: "otro"), [])
    }

    func testProposalsRoundTripOutsideTheWorkspace() throws {
        try store.saveProposals([item.proposal], batch: "b1")
        XCTAssertEqual(store.proposals(batch: "b1"), [item.proposal])
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("estado/propuestas/b1.json").path))
    }

    func testActionLogReadingDistinguishesMissingInvalidAndFound() throws {
        XCTAssertEqual(store.actionLog(batch: "b1").isMissing, true)
        let file = FileExecutionStateStore.actionLogFile(batch: "b1", in: folder.appendingPathComponent("workspace/ejecuciones"))
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{roto".utf8).write(to: file)
        XCTAssertEqual(store.actionLog(batch: "b1").isInvalid, true)
        let log = ActionLog(
            batch: "b1", actions: [ActionRecord(itemId: "li:1", action: .apply, target: item.proposal.target, outcome: .done, at: moment)])
        try FileExecutionStateStore.encoder.encode(log).write(to: file)
        guard case .found(let found) = store.actionLog(batch: "b1") else { return XCTFail("debía leer el registro") }
        XCTAssertEqual(found.actions.count, 1)
    }

    func testConsumedActionsCountEverySentActionOfTheAgentByVerificationTime() throws {
        let jobs = AgentID(rawValue: "empleo")
        let done = ActionRecord(itemId: "li:1", action: .apply, target: item.proposal.target, outcome: .done, at: .distantPast)
        let pending = ActionRecord(itemId: "li:2", action: .apply, target: item.proposal.target, outcome: .pending, at: moment)
        let stranger = ActionRecord(itemId: "li:9", action: .apply, target: .url("https://otro.co/x"), outcome: .done, at: moment)
        let verification = ExecutionVerification(
            batch: "b1", unverifiedReason: nil, verdicts: [.authorized(done), .authorized(pending), .unauthorized(stranger, .notApproved)])
        try store.save(verification, agent: jobs)
        try store.save(
            ExecutionVerification(batch: "b2", unverifiedReason: nil, verdicts: [.authorized(done)]), agent: AgentID(rawValue: "freelance"))
        XCTAssertEqual(store.consumedActions(agent: jobs, since: moment.addingTimeInterval(-60)), 2)
        XCTAssertEqual(store.consumedActions(agent: jobs, since: moment.addingTimeInterval(60)), 0)
    }

    func testApprovedButUnverifiedItemsReserveQuotaUntilVerifiedOrReleased() throws {
        let jobs = AgentID(rawValue: "empleo")
        try store.saveApproved([item], batch: "b1", agent: jobs)
        XCTAssertEqual(store.consumedActions(agent: jobs, since: moment.addingTimeInterval(-60)), 1)
        XCTAssertEqual(store.consumedActions(agent: AgentID(rawValue: "freelance"), since: moment.addingTimeInterval(-60)), 0)
        try store.save(ExecutionVerification(batch: "b1", unverifiedReason: nil, verdicts: [.missing("li:1")]), agent: jobs)
        XCTAssertEqual(store.consumedActions(agent: jobs, since: moment.addingTimeInterval(-60)), 0)
        try store.saveApproved([item], batch: "b3", agent: jobs)
        try store.releaseApproval(batch: "b3")
        XCTAssertEqual(store.consumedActions(agent: jobs, since: moment.addingTimeInterval(-60)), 0)
    }

    func testContactedTargetsAreOnlyAuthorizedSentActions() throws {
        let jobs = AgentID(rawValue: "empleo")
        let done = ActionRecord(itemId: "li:1", action: .apply, target: item.proposal.target, outcome: .done, at: moment)
        let stranger = ActionRecord(itemId: "li:9", action: .apply, target: .url("https://otro.co/x"), outcome: .done, at: moment)
        try store.save(
            ExecutionVerification(
                batch: "b1", unverifiedReason: nil, verdicts: [.authorized(done), .unauthorized(stranger, .notApproved)]),
            agent: jobs)
        XCTAssertEqual(store.contactedTargets(agent: jobs), [item.proposal.target])
    }

    func testDiscardingTheActionLogRemovesThePreviousRun() throws {
        let file = FileExecutionStateStore.actionLogFile(batch: "b1", in: folder.appendingPathComponent("workspace/ejecuciones"))
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: file)
        try store.discardActionLog(batch: "b1")
        XCTAssertEqual(store.actionLog(batch: "b1").isMissing, true)
        try store.discardActionLog(batch: "b1")
    }

    func testSeenProposalsRoundTripOutsideTheWorkspace() throws {
        try store.saveSeenProposals(["apply linkedin.com/jobs/view/1": moment])
        XCTAssertEqual(store.seenProposals(), ["apply linkedin.com/jobs/view/1": moment])
    }

    func testOldRecordsAreRemoved() throws {
        try store.saveProposals([item.proposal], batch: "b1")
        try store.removeRecords(before: Date().addingTimeInterval(60))
        XCTAssertEqual(store.proposals(batch: "b1"), [])
    }

    func testPauseReplacesThePreviousPauseOfTheSameAgentAndResumeRemovesIt() throws {
        let jobs = AgentID(rawValue: "empleo")
        try store.pause(AgentPause(agent: jobs, batch: "b1", reason: "notApproved", since: moment))
        try store.pause(AgentPause(agent: jobs, batch: "b2", reason: "textMismatch", since: moment))
        try store.pause(AgentPause(agent: AgentID(rawValue: "freelance"), batch: "b3", reason: "logMissing", since: moment))
        XCTAssertEqual(store.pauses().filter { $0.agent == jobs }.map(\.batch), ["b2"])
        try store.resume(jobs)
        XCTAssertEqual(store.pauses().map(\.agent.rawValue), ["freelance"])
    }

    func testFilesWithAnotherSchemaVersionAreIgnored() throws {
        let file = folder.appendingPathComponent("estado/pausas.json")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"schemaVersion": 9, "content": []}"#.utf8).write(to: file)
        XCTAssertEqual(store.pauses(), [])
    }
}

extension ActionLogReading {
    var isMissing: Bool {
        if case .missing = self { return true }
        return false
    }

    var isInvalid: Bool {
        if case .invalid = self { return true }
        return false
    }
}
