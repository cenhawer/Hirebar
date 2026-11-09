import HirebarDomain
import XCTest

@testable import HirebarCore

final class PortalTests: XCTestCase {
    override func setUp() {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-portals-\(UUID().uuidString)")
        setenv("HIREBAR_HOME", home.path, 1)
        Paths.ensure()
    }

    override func tearDown() {
        unsetenv("HIREBAR_HOME")
    }

    func testValidation() {
        XCTAssertTrue(CustomPortal(name: "Torre", agent: .jobs, url: "https://torre.ai/search").isValid)
        XCTAssertFalse(CustomPortal(name: "", agent: .jobs, url: "https://torre.ai").isValid)
        XCTAssertFalse(CustomPortal(name: "Torre", agent: .jobs, url: "torre.ai").isValid)
        XCTAssertFalse(CustomPortal(name: "Torre", agent: .jobs, url: "https://").isValid)
    }

    func testSaveKeepsOnlyValidAndFiltersByAgent() throws {
        try PortalStore.save([
            CustomPortal(name: " Torre ", agent: .jobs, url: "https://torre.ai/search "),
            CustomPortal(name: "Upwork", agent: .freelance, url: "https://www.upwork.com/nx/search", enabled: false),
            CustomPortal(name: "Roto", agent: .jobs, url: "nada"),
        ])
        let saved = PortalStore.load()
        XCTAssertEqual(saved.map(\.name), ["Torre", "Upwork"])
        XCTAssertEqual(saved.first?.url, "https://torre.ai/search")
        XCTAssertEqual(PortalStore.active(for: .jobs).count, 1)
        XCTAssertTrue(PortalStore.active(for: .freelance).isEmpty)
    }

    func testAgentGetsScanTaskOnce() {
        var agent = AgentSettings(id: .jobs, name: "Empleo", purpose: "")
        agent.ensurePortalScanTask()
        agent.ensurePortalScanTask()
        XCTAssertEqual(agent.tasks.filter { $0.mode == .portalScanJobs }.count, 1)
        var clients = AgentSettings(id: .clients, name: "Clientes", purpose: "")
        clients.ensurePortalScanTask()
        XCTAssertTrue(clients.tasks.isEmpty)
    }
}
