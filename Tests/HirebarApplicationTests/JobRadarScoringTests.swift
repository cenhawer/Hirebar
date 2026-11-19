import Foundation
import HirebarDomain
import XCTest

@testable import HirebarApplication

@MainActor
final class JobRadarScoringTests: XCTestCase {
    let profile: JobProfile = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/perfil-busqueda.json")
        guard let data = try? Data(contentsOf: url), let profile = try? SearchProfile.decode(data, over: nil) else {
            fatalError("Resources/perfil-busqueda.json no se pudo leer")
        }
        return profile.jobs
    }()

    func hit(_ id: String) -> Hit {
        Hit(id: id, platform: "Portal de prueba", fit: .strong, title: id, url: "https://example.com/\(id)", detail: "remoto", score: 0)
    }

    func testHitsOrderByTotalScoreDescending() {
        let high = JobRadar.scored(
            hit("high"), text: "Backend Node Nest TypeScript, 2 años de experiencia, remoto desde Colombia.",
            location: "Colombia", profile: profile)
        let mid = JobRadar.scored(
            hit("mid"), text: "Backend Node Go, 2 años de experiencia, remoto desde Colombia.", location: "Colombia", profile: profile)
        let low = JobRadar.scored(
            hit("low"), text: "Ingeniero Go Scala Kotlin, 2 años de experiencia, remoto desde Colombia.", location: "Colombia",
            profile: profile)

        let sorted = [low, high, mid].sorted(by: Hit.ranked)

        XCTAssertEqual(sorted.map(\.id), ["high", "mid", "low"])
    }

    func testTiedScoresKeepArrivalOrder() {
        let first = JobRadar.scored(hit("first"), text: "Desarrollador NestJS.", location: "", profile: profile)
        let second = JobRadar.scored(hit("second"), text: "Desarrollador NestJS.", location: "", profile: profile)

        let sorted = [first, second].sorted(by: Hit.ranked)

        XCTAssertEqual(sorted.map(\.id), ["first", "second"])
    }

    func testScoredHitDetailIncludesBreakdownLines() {
        let scored = JobRadar.scored(hit("with-detail"), text: "Desarrollador NestJS.", location: "", profile: profile)

        XCTAssertTrue(scored.detail.contains("Habilidades"))
        XCTAssertTrue(scored.detail.contains("Experiencia"))
        XCTAssertTrue(scored.detail.contains("Ubicación"))
        XCTAssertTrue(scored.detail.contains("Alineación de carrera"))
    }
}
