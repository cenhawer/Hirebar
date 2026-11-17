import Foundation
import HirebarApplication
import HirebarDomain
import XCTest

@testable import HirebarPortals

struct FixtureFetcher: WebPageFetcher {
    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/portals")
    let routes: [String: String]

    func data(_ url: URL) async -> Data? {
        guard let file = routes.first(where: { url.absoluteString.contains($0.key) })?.value else { return nil }
        return try? Data(contentsOf: Self.folder.appendingPathComponent(file))
    }

    func pause(_ seconds: Double) async {}

    static func page(_ file: String) throws -> String {
        try String(contentsOf: folder.appendingPathComponent(file), encoding: .utf8)
    }
}

final class PortalFixtureTests: XCTestCase {
    static let capturedAt = Date(timeIntervalSince1970: 1_794_314_546)
    static let getOnBoardRemotePublishedAt = Date(timeIntervalSince1970: 1_793_985_774)
    static let fullStackPublishedAt = Date(timeIntervalSince1970: 1_793_811_368)
    let defaults = RepositoryDefaults.searchProfile

    func freelanceProfile(strong: [String]) -> SearchProfile {
        var freelance = RepositoryDefaults.searchProfile.freelance
        freelance.strong = strong
        freelance.hardBlocked = []
        freelance.stackBlocked = []
        freelance.titleBlocked = []
        freelance.titleNever = []
        freelance.whatsappBotWords = []
        freelance.offProfile = []
        freelance.frontendOnly = []
        freelance.minFixedUSD = 0
        freelance.minHourlyUSD = 0
        return SearchProfile(freelance: freelance, jobs: RepositoryDefaults.searchProfile.jobs)
    }

    func testLinkedInCardsBecomeHitsAndSeenOnesAreSkipped() async throws {
        let source = LinkedInSource(fetcher: FixtureFetcher(routes: ["seeMoreJobPostings": "linkedin-busqueda.html"]))
        let found = await source.search(skip: [], profile: defaults).hits
        XCTAssertEqual(found.map(\.id), ["li:4481526128", "li:4489138788", "li:4489133996", found.last?.id ?? ""])
        XCTAssertTrue(found.allSatisfy { $0.url.hasPrefix("https://www.linkedin.com/jobs/view/") })
        let again = await source.search(skip: ["li:4481526128"], profile: defaults).hits
        XCTAssertFalse(again.contains { $0.id == "li:4481526128" })
        let posting = try FixtureFetcher.page("linkedin-vacante.html")
        XCTAssertGreaterThan(source.descriptionText(from: posting)?.count ?? 0, 1000)
        XCTAssertEqual(source.location(from: posting), "Colombia")
    }

    func testWorkanaReadsTheEmbeddedResultsAndTheProposalCount() async throws {
        XCTAssertEqual(WorkanaSource.results(try FixtureFetcher.page("workana-busqueda.html")).count, 8)
        let source = WorkanaSource(
            fetcher: FixtureFetcher(routes: ["/jobs?": "workana-busqueda.html", "/job/": "workana-proyecto.html"]))
        let found = await source.search(skip: [], profile: freelanceProfile(strong: ["web", "desarrollo", "sitio", "optimizar"]))
        let hit = try XCTUnwrap(
            found.hits.first { $0.id == "w:experto-en-desarrollo-web-para-optimizar-y-redisenar-sitio-de-mudanzas-henry" })
        XCTAssertTrue(hit.detail.contains("5 propuestas"))
    }

    func testComputrabajoReadsOffersWithSingleQuotedIdsAndOnlyNotifiesRemoteOnes() async throws {
        let offers = ComputrabajoSource.offers(in: try FixtureFetcher.page("computrabajo-busqueda.html"))
        XCTAssertEqual(offers.map(\.id), ["84F4A65555C15B2F61373E686DCF3405", "1E3877ABFB45693B61373E686DCF3405"])
        XCTAssertEqual(offers.map(\.title), ["Reclutador IT", "Desarrollador Full stack"])
        XCTAssertTrue(offers.allSatisfy { $0.path.hasPrefix("/ofertas-de-trabajo/") && !$0.path.contains("#") })
        let source = ComputrabajoSource(fetcher: FixtureFetcher(routes: ["computrabajo.com/trabajo-de-": "computrabajo-busqueda.html"]))
        let found = await source.search(skip: [], profile: defaults)
        XCTAssertTrue(found.hits.isEmpty)
    }

    func testElempleoReadsOfferDataAndOnlyNotifiesRemoteOnes() async throws {
        let offers = ElempleoSource.offers(in: try FixtureFetcher.page("elempleo-busqueda.html"))
        XCTAssertEqual(offers.count, 9)
        XCTAssertEqual(offers.first?.title, "Desarrollador apex")
        XCTAssertEqual(offers.first?.modality, "- Hibrido")
        XCTAssertTrue(offers.allSatisfy { !$0.id.isEmpty && $0.path.hasPrefix("/co/ofertas-trabajo/") && !$0.path.contains("?") })
        let source = ElempleoSource(fetcher: FixtureFetcher(routes: ["ofertas-empleo": "elempleo-busqueda.html"]))
        let found = await source.search(skip: [], profile: defaults)
        XCTAssertTrue(found.hits.isEmpty)
    }

    func testMagnetoTurnsOfferLinksIntoHits() async {
        let source = MagnetoSource(
            fetcher: FixtureFetcher(routes: ["ofertas-empleo-de-": "magneto-busqueda.html"]), now: { Self.capturedAt })
        let found = await source.search(skip: [], profile: defaults).hits
        XCTAssertEqual(found.map(\.id), ["mg:1626436242", "mg:1094241"])
        XCTAssertEqual(found.first?.title, "Desarrolladora De Software Full Stack Senior")
    }

    func testFreelancerKeepsRecentSpanishProjectsWithFewBids() async {
        let source = FreelancerSource(
            fetcher: FixtureFetcher(routes: ["projects/active": "freelancer-proyectos.json"]), now: { Self.capturedAt })
        let found = await source.search(skip: [], profile: freelanceProfile(strong: ["video"]))
        XCTAssertEqual(Set(found.hits.map(\.id)), ["f:40810767", "f:40810427"])
        XCTAssertTrue(found.hits.allSatisfy { $0.url.hasPrefix("https://www.freelancer.com/projects/") })
        let later = FreelancerSource(
            fetcher: FixtureFetcher(routes: ["projects/active": "freelancer-proyectos.json"]),
            now: { Self.capturedAt.addingTimeInterval(3 * 86400) })
        let stale = await later.search(skip: [], profile: freelanceProfile(strong: ["video"]))
        XCTAssertTrue(stale.hits.isEmpty)
    }

    func testGetOnBoardKeepsRemoteSpanishOffersForThePersonCountry() async {
        var jobs = RepositoryDefaults.searchProfile.jobs
        jobs.country = "remoto"
        let source = GetOnBoardSource(
            fetcher: FixtureFetcher(routes: ["search/jobs": "getonboard-busqueda.json"]),
            now: { Self.fullStackPublishedAt.addingTimeInterval(3600) })
        let found = await source.search(skip: [], profile: SearchProfile(freelance: RepositoryDefaults.searchProfile.freelance, jobs: jobs))
            .hits
        XCTAssertEqual(Set(found.map(\.id)), ["gob:desarrollador-a-full-stack-frontend-datos-bc-tecnologia-remote"])
    }

    func testGetOnBoardDiscardsOffersThatRequireAdvancedEnglish() async {
        let source = GetOnBoardSource(
            fetcher: FixtureFetcher(routes: ["search/jobs": "getonboard-busqueda.json"]),
            now: { Self.getOnBoardRemotePublishedAt.addingTimeInterval(3600) })
        let found = await source.search(skip: [], profile: defaults).hits
        XCTAssertFalse(found.contains { $0.id == "gob:desarrollador-semi-senior-vue-y-c-net-alluxi-remote-d2a3" })
    }
}
