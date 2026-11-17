import Foundation
import HirebarApplication
import HirebarDomain
import XCTest

@testable import HirebarStorage

final class HousekeepingTests: XCTestCase {
    static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-housekeeping-\(UUID().uuidString)")
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let policy = RepositoryDefaults.retention

    override static func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override static func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    override func setUpWithError() throws {
        try? FileManager.default.removeItem(at: Self.home)
        Paths.ensure()
    }

    @discardableResult
    func file(_ url: URL, age: TimeInterval) throws -> URL {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-age)], ofItemAtPath: url.path)
        return url
    }

    func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    func testOldVoiceRecordingsAndVideosAreDeletedAndRecentOnesKept() throws {
        let video = Paths.content.appendingPathComponent("empresa/video", isDirectory: true)
        let oldRecording = try file(video.appendingPathComponent("grabacion.oga"), age: policy.recordings + 60)
        let oldVoice = try file(video.appendingPathComponent("mi-voz.m4a"), age: policy.recordings + 60)
        let recentRecording = try file(video.appendingPathComponent("grabacion.m4a"), age: 60)
        let oldReel = try file(video.appendingPathComponent("reel.mp4"), age: policy.videos + 60)
        let script = try file(video.appendingPathComponent("guion.json"), age: policy.videos + 60)
        Housekeeping.run(policy: policy, at: now)
        XCTAssertFalse(exists(oldRecording))
        XCTAssertFalse(exists(oldVoice))
        XCTAssertFalse(exists(oldReel))
        XCTAssertTrue(exists(recentRecording))
        XCTAssertTrue(exists(script))
    }

    func testDiscardedDraftsEmailListsAndOldRunsFollowThePolicy() throws {
        let draft = try file(Paths.content.appendingPathComponent("empresa/descartado-2026-01-01-1.md"), age: policy.discarded + 60)
        let current = try file(Paths.content.appendingPathComponent("empresa/borrador.md"), age: policy.discarded + 60)
        let emails = try file(Paths.prospecting.appendingPathComponent("descartados-1.json"), age: policy.discarded + 60)
        let oldRun = try file(Paths.runs.appendingPathComponent("lote.log"), age: policy.runs + 60)
        let recentRun = try file(Paths.runs.appendingPathComponent("nuevo.log"), age: 60)
        Housekeeping.run(policy: policy, at: now)
        XCTAssertFalse(exists(draft))
        XCTAssertFalse(exists(emails))
        XCTAssertFalse(exists(oldRun))
        XCTAssertTrue(exists(current))
        XCTAssertTrue(exists(recentRun))
    }

    func testTheRetentionPolicyRejectsEmptyWindowsAndUnknownVersions() throws {
        let file = RepositoryDefaults.resources.appendingPathComponent("retencion.json")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        object["grabacionesDias"] = 0
        XCTAssertThrowsError(try RetentionPolicy.decode(JSONSerialization.data(withJSONObject: object))) {
            XCTAssertEqual($0 as? ResourceFailure, .invalidValues)
        }
        object["grabacionesDias"] = 14
        object["schemaVersion"] = 2
        XCTAssertThrowsError(try RetentionPolicy.decode(JSONSerialization.data(withJSONObject: object))) {
            XCTAssertEqual($0 as? ResourceFailure, .unsupportedVersion(2))
        }
        XCTAssertEqual(policy.recordings, 14 * 86400)
    }
}
