import XCTest

@testable import HirebarDomain

final class JobScoreBreakdownTests: XCTestCase {
    static let profile: JobProfile = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/perfil-busqueda.json")
        guard let data = try? Data(contentsOf: url), let profile = try? SearchProfile.decode(data, over: nil) else {
            fatalError("Resources/perfil-busqueda.json no se pudo leer")
        }
        return profile.jobs
    }()

    let profile = JobScoreBreakdownTests.profile

    func testStrongVacancyNeverScoresBajo() {
        let text = "Backend NestJS y TypeScript en AWS, microservicios, trabajo 100% remoto desde Colombia."
        let breakdown = JobScreener.score(text, location: "Colombia", profile: profile)
        for dimension in ScoreDimension.allCases {
            XCTAssertNotEqual(breakdown.level(for: dimension), .bajo, "\(dimension) no debería quedar en bajo")
        }
    }

    func testExperienceAboveLimitScoresBajoIndependently() {
        let text = "Desarrollador Java Spring Boot con 7 años de experiencia, 100% remoto."
        let breakdown = JobScreener.score(text, profile: profile)
        XCTAssertEqual(breakdown.level(for: .experience), .bajo)
    }

    func testMissingDimensionScoresSinDatos() {
        let text = "Desarrollador NestJS."
        let breakdown = JobScreener.score(text, profile: profile)
        XCTAssertEqual(breakdown.level(for: .location), .sinDatos)
    }

    func testLinesFollowRequiredOrder() {
        let breakdown = JobScreener.score("Desarrollador NestJS.", profile: profile)
        XCTAssertEqual(breakdown.lines.count, 4)
        XCTAssertTrue(breakdown.lines[0].hasPrefix("Habilidades"))
        XCTAssertTrue(breakdown.lines[1].hasPrefix("Experiencia"))
        XCTAssertTrue(breakdown.lines[2].hasPrefix("Ubicación"))
        XCTAssertTrue(breakdown.lines[3].hasPrefix("Alineación de carrera"))
    }

    func testZeroWeightDimensionDoesNotAffectTotal() {
        let weights = ScoringWeights(skills: 100, experience: 0, location: 0, careerFit: 0)
        let allHigh = JobScoreBreakdown(
            scores: [
                DimensionScore(dimension: .skills, level: .alto),
                DimensionScore(dimension: .experience, level: .bajo),
                DimensionScore(dimension: .location, level: .bajo),
                DimensionScore(dimension: .careerFit, level: .bajo),
            ],
            weights: weights
        )
        let onlySkills = JobScoreBreakdown(
            scores: [DimensionScore(dimension: .skills, level: .alto)], weights: weights)
        XCTAssertEqual(allHigh.total, onlySkills.total)
    }

    func testWeightsNormalizeWhenTheyDoNotSumToHundred() {
        let unnormalized = ScoringWeights(skills: 10, experience: 10, location: 10, careerFit: 10)
        let normalized = unnormalized.normalized()
        XCTAssertEqual(normalized.skills + normalized.experience + normalized.location + normalized.careerFit, 100, accuracy: 0.001)
        XCTAssertEqual(normalized.skills, normalized.experience)
    }
}
