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

    func testAScheduledSlotRunsOnlyOnceAndSeenHitsAreKept() throws {
        let suite = "hirebar.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = DefaultsRunStateRepository(defaults: defaults)
        XCTAssertTrue(state.claim("sched.jobs.2026-11-09"))
        XCTAssertFalse(state.claim("sched.jobs.2026-11-09"))
        let moment = Date(timeIntervalSince1970: 1_800_000_000)
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
