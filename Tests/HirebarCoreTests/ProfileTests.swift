import HirebarDomain
import XCTest

@testable import HirebarCore

final class ProfileTests: XCTestCase {
    let profile = Profile(skills: [
        Skill(name: "Go", level: .familiar, aliases: ["golang"]),
        Skill(name: "Elixir", level: .expert),
        Skill(name: "Python", level: .avoid),
    ])

    func testSkillsExtendSearchTerms() {
        let effective = SearchProfile.defaults.applying(profile)
        XCTAssertTrue(effective.jobs.strong.contains("elixir"))
        XCTAssertTrue(effective.freelance.strong.contains("elixir"))
        XCTAssertTrue(effective.jobs.weak.contains("golang"))
        XCTAssertTrue(effective.freelance.stretch.contains("go"))
        XCTAssertTrue(effective.jobs.blocked.contains("python"))
        XCTAssertFalse(effective.freelance.stretch.contains("python"))
    }

    func testAvoidedSkillChangesClassification() {
        let before = SearchProfile.defaults
        let after = before.applying(profile)
        XCTAssertTrue(before.freelance.stretch.contains("python"))
        XCTAssertTrue(after.freelance.titleBlocked.contains("python"))
    }

    func testEmptyProfileKeepsDefaults() {
        let effective = SearchProfile.defaults.applying(Profile())
        XCTAssertEqual(effective.jobs.strong, JobProfile.defaults.strong)
        XCTAssertEqual(effective.freelance.stretch, FreelanceProfile.defaults.stretch)
    }

    func testParseLevels() {
        XCTAssertEqual(SkillLevel.parse("Dominio"), .expert)
        XCTAssertEqual(SkillLevel.parse("conozco"), .familiar)
        XCTAssertEqual(SkillLevel.parse("evito"), .avoid)
        XCTAssertNil(SkillLevel.parse("tal vez"))
    }

    func testEditorKeepsOtherFields() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("perfil-\(UUID().uuidString).json")
        let json = #"{"person": {"name": "Ana"}, "skills": [{"name": "Go", "level": "conozco", "aliases": ["golang"]}]}"#
        try Data(json.utf8).write(to: url)

        XCTAssertEqual(ProfileEditor.setSkill("go", level: .expert, at: url), .updated(from: .familiar))
        XCTAssertEqual(ProfileEditor.setSkill("Rust", level: .familiar, at: url), .added)
        XCTAssertEqual(ProfileEditor.setSkill("Rust", level: .familiar, at: url), .unchanged)

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual((object["person"] as? [String: Any])?["name"] as? String, "Ana")
        let decoded = try JSONDecoder().decode(Profile.self, from: Data(contentsOf: url))
        XCTAssertEqual(decoded.skill(named: "golang")?.level, .expert)
        XCTAssertEqual(decoded.skills.count, 2)
    }

    func testTemplateProfileDecodes() throws {
        let template = URL(fileURLWithPath: #filePath).resolvingSymlinksInPath()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/inicial/perfil.json")
        let profile = try JSONDecoder().decode(Profile.self, from: Data(contentsOf: template))
        XCTAssertFalse(profile.skills.isEmpty)
        XCTAssertEqual(profile.cvVariants.first?.id, "node")
    }
}

final class SaveSkillsTests: XCTestCase {
    func testSaveSkillsKeepsTheRestOfTheProfile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("perfil-\(UUID().uuidString).json")
        try Data(#"{"person": {"name": "Ana"}, "cvVariants": [], "skills": []}"#.utf8).write(to: url)
        try ProfileEditor.saveSkills([
            Skill(name: " Go ", level: .familiar, years: 1, aliases: ["golang", " "]),
            Skill(name: "  ", level: .expert),
        ], at: url)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual((object["person"] as? [String: Any])?["name"] as? String, "Ana")
        let profile = try JSONDecoder().decode(Profile.self, from: Data(contentsOf: url))
        XCTAssertEqual(profile.skills, [Skill(name: "Go", level: .familiar, years: 1, aliases: ["golang"])])
    }
}
