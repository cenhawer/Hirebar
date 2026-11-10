import Foundation
import HirebarDomain
import XCTest

@testable import HirebarApplication

struct FakeListingSource: ListingSource {
    let id: String
    let name: String
    let hits: [Hit]

    func search(skip: Set<String>, profile: SearchProfile) async -> SourceResult {
        SourceResult(hits: hits.filter { !skip.contains($0.id) })
    }
}

struct FakeJobSource: JobSource {
    let id = "fake-empleo"
    let name = "Portal de prueba"
    let hitPrefix = "fake"
    let hits: [Hit]

    func search(skip: Set<String>, profile: SearchProfile) async -> SourceResult {
        SourceResult(hits: hits.filter { !skip.contains($0.id) })
    }

    func descriptionCheck(for hit: Hit) -> DescriptionCheck { .skip }
}

struct SilentFetcher: WebPageFetcher {
    func text(_ address: String) async -> String? { nil }
    func pause(_ seconds: Double) async {}
}

@MainActor
final class RadarTests: XCTestCase {
    nonisolated static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-radar-\(UUID().uuidString)")
    var harness: EngineHarness!

    override static func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override static func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    override func setUp() async throws {
        harness = EngineHarness()
        harness.stores.agents.update(.freelance) {
            $0.enabled = true
            $0.autoApprove = false
        }
        harness.stores.agents.update(.jobs) {
            $0.enabled = true
            $0.autoApprove = false
        }
    }

    func hit(_ id: String, platform: String, fit: Fit = .strong) -> Hit {
        Hit(id: id, platform: platform, fit: fit, title: "App \(id)", url: "https://example.com/\(id)", detail: "remoto", score: 10)
    }

    func portals(freelance: [ListingSource] = [], jobs: [JobSource] = []) -> PortalAccess {
        PortalAccess(jobs: jobs, freelance: freelance, fetcher: SilentFetcher())
    }

    func pendingList(_ mode: Mode) -> Batch? {
        harness.stores.batches.load().last { $0.mode == mode && $0.status == .pending }
    }

    func waitForResult(of radar: Radar) async {
        let finished = expectation(description: "radar")
        radar.onStatusChange = { status in
            if status != "buscando…" { finished.fulfill() }
        }
        radar.checkNow()
        await fulfillment(of: [finished], timeout: 2)
    }

    func testFreelanceFindingsBecomeAPendingListAndAreRemembered() async throws {
        let source = FakeListingSource(id: "fake-freelance", name: "Portal", hits: [hit("p1", platform: "Portal")])
        let radar = FreelanceRadar(stores: harness.stores, clock: harness.clock, portals: portals(freelance: [source]))
        radar.controller = harness.controller
        await waitForResult(of: radar)
        let batch = try XCTUnwrap(pendingList(.freelance))
        XCTAssertEqual(batch.items.map(\.id), ["p1"])
        XCTAssertNotNil(harness.runState.seen("radar.seen")["p1"])
    }

    func testAlreadySeenProjectsAreNotAnnouncedAgain() async {
        harness.runState.saveSeen(["p1": harness.clock.now()], key: "radar.seen")
        let before = harness.stores.batches.load().count
        let source = FakeListingSource(id: "fake-freelance", name: "Portal", hits: [hit("p1", platform: "Portal")])
        let radar = FreelanceRadar(stores: harness.stores, clock: harness.clock, portals: portals(freelance: [source]))
        await waitForResult(of: radar)
        XCTAssertTrue(radar.status.hasSuffix("nada nuevo"))
        XCTAssertEqual(harness.stores.batches.load().count, before)
    }

    func testJobFindingsPreferStrongFitsOverStretchOnes() async throws {
        let source = FakeJobSource(hits: [
            hit("fake:1", platform: "Portal de prueba"), hit("fake:2", platform: "Portal de prueba", fit: .stretch),
        ])
        let radar = JobRadar(stores: harness.stores, clock: harness.clock, portals: portals(jobs: [source]))
        radar.controller = harness.controller
        await waitForResult(of: radar)
        let batch = try XCTUnwrap(pendingList(.jobs))
        XCTAssertEqual(batch.items.map(\.id), ["fake:1"])
    }

    func testATurnedOffRadarDoesNotSearch() {
        harness.stores.agents.update(.jobs) { $0.enabled = false }
        let radar = JobRadar(stores: harness.stores, clock: harness.clock, portals: portals(jobs: [FakeJobSource(hits: [])]))
        radar.checkNow()
        XCTAssertEqual(radar.status, "apagado")
    }
}
