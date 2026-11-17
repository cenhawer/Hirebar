import Foundation
import HirebarApplication
import HirebarDomain
import XCTest

@testable import HirebarStorage

final class ExecutionActivityTests: XCTestCase {
    var folder: URL!
    var store: FileExecutionStateStore!
    let moment = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = FileExecutionStateStore(
            stateFolder: folder.appendingPathComponent("estado"), runsFolder: folder.appendingPathComponent("ejecuciones"),
            now: { [moment] in moment })
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func record(_ id: String, outcome: ActionOutcome = .done, text: String? = "Hola, me interesa") -> ActionRecord {
        ActionRecord(
            itemId: id, action: .sendEmail, target: .email("\(id)@acme.co"), sentText: text, outcome: outcome, at: moment)
    }

    func testEachVerifiedSendShowsWhatToWhomWhenAndWithWhichText() throws {
        let verification = ExecutionVerification(
            batch: "c1", unverifiedReason: nil,
            verdicts: [
                .authorized(record("ana")), .unauthorized(record("otro"), .notApproved), .missing("nadie"),
                .authorized(record("luego", outcome: .pending)),
            ])
        try store.save(verification, agent: AgentID(rawValue: "clientes"))
        let entries = store.activity()
        XCTAssertEqual(entries.map(\.outcome), [.sent, .rejected])
        let sent = try XCTUnwrap(entries.first)
        XCTAssertEqual(sent.agent.rawValue, "clientes")
        XCTAssertEqual(sent.target, .email("ana@acme.co"))
        XCTAssertEqual(sent.text, "Hola, me interesa")
        XCTAssertEqual(sent.at, moment)
        XCTAssertEqual(sent.batch, "c1")
    }

    func testPracticeRunsShowWhatWouldHaveBeenSent() throws {
        let proposal = Proposal(
            id: "li:1", action: .apply, target: .url("https://linkedin.com/jobs/view/1"), title: "Backend", source: "LinkedIn")
        try PracticeLog(batch: "e1", agent: "empleo", at: moment, wouldSend: [proposal]).save(
            in: folder.appendingPathComponent("ejecuciones"))
        let entries = store.activity()
        XCTAssertEqual(entries.map(\.outcome), [.practice])
        XCTAssertEqual(entries.first?.action, .apply)
        XCTAssertEqual(entries.first?.agent.rawValue, "empleo")
    }
}
