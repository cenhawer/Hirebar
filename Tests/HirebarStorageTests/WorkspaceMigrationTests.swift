import Foundation
import HirebarApplication
import HirebarDomain
import XCTest

@testable import HirebarStorage

final class WorkspaceMigrationTests: XCTestCase {
    static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-migration-\(UUID().uuidString)")
    let moment = Date(timeIntervalSince1970: 1_800_000_000)
    let weeklySlot = "sched.semanal.2026-11-09"
    var suite = ""
    var defaults: UserDefaults!

    override static func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override static func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    override func setUpWithError() throws {
        try? FileManager.default.removeItem(at: Self.home)
        Paths.ensure()
        suite = "hirebar.migration.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func json(_ url: URL) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(contentsOf: url))
    }

    func testLegacyFilesGetAVersionAndABackupWithoutLosingData() throws {
        try Data(#"{"ownerName": "Ana"}"#.utf8).write(to: Paths.config)
        try FileManager.default.createDirectory(at: Paths.content, withIntermediateDirectories: true)
        try Data(#"[{"id": "empresa"}]"#.utf8).write(to: ContentAccountStore.url)
        WorkspaceMigration.run(
            defaults: defaults, runState: FileRunStateRepository(claimRetention: RepositoryDefaults.retention.claims), at: moment)
        let config = try XCTUnwrap(json(Paths.config) as? [String: Any])
        XCTAssertEqual(config[WorkspaceSchema.versionKey] as? Int, WorkspaceSchema.current)
        XCTAssertEqual(Config.load().ownerName, "Ana")
        let accounts = try XCTUnwrap(json(ContentAccountStore.url) as? [String: Any])
        XCTAssertEqual(accounts[WorkspaceSchema.versionKey] as? Int, WorkspaceSchema.current)
        XCTAssertEqual(ContentAccountStore.load().map(\.id), ["empresa"])
        let backups = try FileManager.default.contentsOfDirectory(atPath: Paths.backups.path).sorted()
        XCTAssertEqual(backups, ["config.v0.1800000000.json", "workspace-contenido-cuentas.v0.1800000000.json"])
    }

    func testAlreadyVersionedFilesAreLeftAlone() throws {
        Config().save()
        let before = try Data(contentsOf: Paths.config)
        WorkspaceMigration.run(
            defaults: defaults, runState: FileRunStateRepository(claimRetention: RepositoryDefaults.retention.claims), at: moment)
        XCTAssertEqual(try Data(contentsOf: Paths.config), before)
        XCTAssertTrue((try FileManager.default.contentsOfDirectory(atPath: Paths.backups.path)).isEmpty)
    }

    func testAFileFromANewerVersionIsNotOverwritten() throws {
        let newer = Data(#"{"schemaVersion": 99, "ownerName": "Ana"}"#.utf8)
        try newer.write(to: Paths.config)
        Config().save()
        WorkspaceMigration.run(
            defaults: defaults, runState: FileRunStateRepository(claimRetention: RepositoryDefaults.retention.claims), at: moment)
        XCTAssertEqual(try Data(contentsOf: Paths.config), newer)
    }

    func testRunStateMovesOutOfTheSystemPreferences() throws {
        defaults.set(["li:1": moment], forKey: "jobradar.seen")
        defaults.set("empresa", forKey: "video.esperandoVoz")
        defaults.set(42, forKey: "telegram.offset")
        defaults.set(true, forKey: weeklySlot)
        let state = FileRunStateRepository(now: { [moment] in moment }, claimRetention: RepositoryDefaults.retention.claims)
        WorkspaceMigration.run(defaults: defaults, runState: state, at: moment)
        XCTAssertEqual(state.seen("jobradar.seen"), ["li:1": moment])
        XCTAssertEqual(state.waitingVoiceAccount(), "empresa")
        XCTAssertEqual(state.chatOffset(), 42)
        XCTAssertFalse(state.claim(weeklySlot))
        for key in ["jobradar.seen", "video.esperandoVoz", "telegram.offset", weeklySlot] {
            XCTAssertNil(defaults.object(forKey: key), key)
        }
    }
}
