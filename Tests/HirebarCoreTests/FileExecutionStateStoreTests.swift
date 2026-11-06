import HirebarDomain
import XCTest

@testable import HirebarCore

final class FileExecutionStateStoreTests: XCTestCase {
    var folder: URL!
    var store: FileExecutionStateStore!
    let moment = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = FileExecutionStateStore(
            stateFolder: folder.appendingPathComponent("estado"),
            runsFolder: folder.appendingPathComponent("workspace/ejecuciones")
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
        try store.saveApproved([item], batch: "b1")
        XCTAssertEqual(store.approvedItems(batch: "b1"), [item])
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("estado/aprobados/b1.json").path))
        XCTAssertEqual(store.approvedItems(batch: "otro"), [])
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
