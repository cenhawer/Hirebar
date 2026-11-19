import Foundation
import HirebarApplication
import HirebarDomain
import XCTest

@testable import HirebarStorage

final class FreelanceLooseningTests: XCTestCase {
    static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-loosening-\(UUID().uuidString)")
    let moment = Date(timeIntervalSince1970: 1_800_000_000)
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
        try FileManager.default.createDirectory(at: AgentStore.folder, withIntermediateDirectories: true)
        suite = "hirebar.loosening.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    var upgrades: WorkspaceUpgrades {
        get throws { try WorkspaceUpgrades.load(from: RepositoryDefaults.resources.appendingPathComponent("migraciones.json")) }
    }

    func migrate() throws {
        WorkspaceMigration.run(
            defaults: defaults, runState: FileRunStateRepository(claimRetention: RepositoryDefaults.retention.claims),
            upgrades: try upgrades, at: moment)
    }

    func freelance(_ url: URL) throws -> [String: Any] {
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return try XCTUnwrap(root["freelance"] as? [String: Any])
    }

    func testAnExistingFreelanceSearchProfileIsLoosenedOnceWithABackup() throws {
        let before = #"""
            {"freelance": {"titleNever": ["bot", "ia", "landing", "pagina web"], "offProfile": ["excel", "marketing", "research"],
             "stretch": ["python", "html"], "minFixedUSD": 80}}
            """#
        try Data(before.utf8).write(to: Paths.searchProfile)
        try migrate()
        let after = try freelance(Paths.searchProfile)
        XCTAssertEqual(after["titleNever"] as? [String], ["bot"])
        XCTAssertEqual(after["offProfile"] as? [String], ["marketing"])
        XCTAssertEqual(
            after["stretch"] as? [String], ["python", "html", "pagina web", "sitio web", "landing", "landing page", "css", "excel"])
        XCTAssertEqual(after["minFixedUSD"] as? Int, 80)
        XCTAssertEqual(VersionedJSON.version(of: try Data(contentsOf: Paths.searchProfile)), WorkspaceSchema.current)
        let backups = try FileManager.default.contentsOfDirectory(atPath: Paths.backups.path)
        XCTAssertTrue(backups.contains("workspace-search-profile.v0.1800000000.json"))

        var edited = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: Paths.searchProfile)) as? [String: Any])
        var lists = after
        lists["titleNever"] = ["bot", "ia"]
        edited["freelance"] = lists
        try JSONSerialization.data(withJSONObject: edited).write(to: Paths.searchProfile)
        try migrate()
        XCTAssertEqual(try freelance(Paths.searchProfile)["titleNever"] as? [String], ["bot", "ia"])
    }

    func testTheLoosenedProfileIsWhatTheEngineReads() throws {
        try Data(#"{"freelance": {"titleNever": ["ia", "bot"]}}"#.utf8).write(to: Paths.searchProfile)
        try migrate()
        let profile = SearchProfile.load(defaults: RepositoryDefaults.searchProfile)
        XCTAssertEqual(profile.freelance.titleNever, ["bot"])
        XCTAssertEqual(profile.freelance.aiWords, RepositoryDefaults.searchProfile.freelance.aiWords)
    }

    func testTheFreelanceDailyLimitRisesToTheMinimumOnlyWhenItIsLower() throws {
        try Data(#"{"id": "freelance", "dailyLimit": 5, "schemaVersion": 1}"#.utf8).write(to: AgentStore.url(for: .freelance))
        try Data(#"{"id": "empleo", "dailyLimit": 5, "schemaVersion": 1}"#.utf8).write(to: AgentStore.url(for: .jobs))
        try migrate()
        XCTAssertEqual(AgentStore.load(.freelance).dailyLimit, try upgrades.freelanceMasAbierto.cupoDiarioMinimo)
        XCTAssertEqual(AgentStore.load(.jobs).dailyLimit, 5)

        try Data(#"{"id": "freelance", "dailyLimit": 30, "schemaVersion": 1}"#.utf8).write(to: AgentStore.url(for: .freelance))
        try migrate()
        XCTAssertEqual(AgentStore.load(.freelance).dailyLimit, 30)

        try Data(#"{"id": "freelance", "dailyLimit": 3}"#.utf8).write(to: AgentStore.url(for: .freelance))
        try migrate()
        AgentStore.update(.freelance) { $0.dailyLimit = 3 }
        try migrate()
        XCTAssertEqual(AgentStore.load(.freelance).dailyLimit, 3)
    }

    func testANewInstallStartsLoosenedAndIsNotMigratedAgain() throws {
        let template = RepositoryDefaults.resources.appendingPathComponent("inicial/search-profile.json")
        XCTAssertEqual(VersionedJSON.version(of: try Data(contentsOf: template)), WorkspaceSchema.current)
        let change = try upgrades.freelanceMasAbierto
        let lists = try freelance(template)
        let titleNever = try XCTUnwrap(lists["titleNever"] as? [String])
        let offProfile = try XCTUnwrap(lists["offProfile"] as? [String])
        let stretch = try XCTUnwrap(lists["stretch"] as? [String])
        XCTAssertTrue(change.quitarDeTitleNever.allSatisfy { !titleNever.contains($0) })
        XCTAssertTrue(change.quitarDeOffProfile.allSatisfy { !offProfile.contains($0) })
        XCTAssertTrue(change.agregarAStretch.allSatisfy { stretch.contains($0) })
        XCTAssertEqual(AgentSettings.defaults(for: .freelance).dailyLimit, change.cupoDiarioMinimo)

        Paths.installTemplates(from: RepositoryDefaults.resources)
        let installed = try Data(contentsOf: Paths.searchProfile)
        try migrate()
        XCTAssertEqual(try Data(contentsOf: Paths.searchProfile), installed)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: Paths.backups.path).contains { $0.contains("search-profile") })
    }

    func testTheUpgradeFileRejectsUnknownVersionsAndAnEmptyLimit() throws {
        let file = RepositoryDefaults.resources.appendingPathComponent("migraciones.json")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        object["schemaVersion"] = 2
        XCTAssertThrowsError(try WorkspaceUpgrades.decode(JSONSerialization.data(withJSONObject: object))) {
            XCTAssertEqual($0 as? ResourceFailure, .unsupportedVersion(2))
        }
        object["schemaVersion"] = 1
        var loosening = try XCTUnwrap(object["freelanceMasAbierto"] as? [String: Any])
        loosening["cupoDiarioMinimo"] = 0
        object["freelanceMasAbierto"] = loosening
        XCTAssertThrowsError(try WorkspaceUpgrades.decode(JSONSerialization.data(withJSONObject: object))) {
            XCTAssertEqual($0 as? ResourceFailure, .invalidValues)
        }
    }
}

final class TemplateUpdateTests: XCTestCase {
    static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-templates-\(UUID().uuidString)")
    static let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/plantillas")

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

    func testTheFollowUpRulesFromTheLastReleaseAreReplacedButEditedOnesAreKept() throws {
        let installed = Paths.workspaceFile("instrucciones-seguimiento.md")
        let bundled = RepositoryDefaults.resources.appendingPathComponent("inicial/instrucciones-seguimiento.md")
        try FileManager.default.copyItem(at: Self.fixtures.appendingPathComponent("instrucciones-seguimiento-0.2.0.md"), to: installed)
        Paths.installTemplates(from: RepositoryDefaults.resources)
        XCTAssertEqual(try Data(contentsOf: installed), try Data(contentsOf: bundled))
        XCTAssertTrue(try String(contentsOf: installed, encoding: .utf8).contains("Fiverr"))

        try Data("mis reglas".utf8).write(to: installed)
        Paths.installTemplates(from: RepositoryDefaults.resources)
        XCTAssertEqual(try String(contentsOf: installed, encoding: .utf8), "mis reglas")
    }
}
