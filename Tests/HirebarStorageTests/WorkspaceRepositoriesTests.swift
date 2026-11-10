import Foundation
import XCTest

@testable import HirebarStorage

final class WorkspaceRepositoriesTests: XCTestCase {
    var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func testDiscardedEmailListIsKeptAsideAndNoLongerOffered() throws {
        let prospecting = FileProspectingRepository(folder: folder)
        try Data("{}".utf8).write(to: folder.appendingPathComponent("pendientes.json"))
        XCTAssertNotNil(prospecting.pendingEmails())
        prospecting.discardPendingEmails(at: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertNil(prospecting.pendingEmails())
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("descartados-1800000000.json").path))
    }

    func testAScheduledSlotRunsOnlyOnceAndRunStateSurvivesARestart() throws {
        let file = folder.appendingPathComponent("corrida.json")
        let moment = Date(timeIntervalSince1970: 1_800_000_000)
        let state = FileRunStateRepository(file: file, now: { moment })
        XCTAssertTrue(state.claim("sched.jobs.2026-11-09"))
        XCTAssertFalse(FileRunStateRepository(file: file, now: { moment }).claim("sched.jobs.2026-11-09"))
        let later = FileRunStateRepository(file: file, now: { moment.addingTimeInterval(15 * 86400) })
        XCTAssertTrue(later.claim("sched.otro"))
        XCTAssertTrue(later.claim("sched.jobs.2026-11-09"))
        state.saveChatOffset(7)
        XCTAssertEqual(FileRunStateRepository(file: file).chatOffset(), 7)
        state.saveSeen(["hit": moment], key: "radar.seen")
        XCTAssertEqual(state.seen("radar.seen"), ["hit": moment])
        state.setWaitingVoiceAccount("empresa")
        XCTAssertEqual(state.waitingVoiceAccount(), "empresa")
    }

    func testOnlyTextLongEnoughIsOfferedToCopy() throws {
        let short = folder.appendingPathComponent("corto.md")
        let long = folder.appendingPathComponent("largo.md")
        try "  hola  ".write(to: short, atomically: true, encoding: .utf8)
        try "\nUna publicación con texto suficiente\n".write(to: long, atomically: true, encoding: .utf8)
        XCTAssertNil(ContentAccountFiles.copyableText(short))
        XCTAssertEqual(ContentAccountFiles.copyableText(long), "Una publicación con texto suficiente")
        XCTAssertNil(ContentAccountFiles.copyableText(folder.appendingPathComponent("nada.md")))
    }
}
