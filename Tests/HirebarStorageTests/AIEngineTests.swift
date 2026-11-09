import HirebarApplication
import HirebarDomain
import XCTest

@testable import HirebarStorage

final class AIEngineTests: XCTestCase {
    func testOldConfigDefaultsToClaude() throws {
        let config = try JSONDecoder().decode(Config.self, from: Data(#"{"chatId": 1}"#.utf8))
        XCTAssertEqual(config.aiEngine.kind, .claude)
    }

    func testCustomCommandsRoundTrip() throws {
        var config = Config()
        config.aiEngine = AIEngineSettings(
            kind: .custom, readCommand: " leer \"$HIREBAR_PROMPT\" ", actCommand: "  mi-ia \"$HIREBAR_PROMPT\"  ")
        let back = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(back.aiEngine.customCommand(for: .read), "leer \"$HIREBAR_PROMPT\"")
        XCTAssertEqual(back.aiEngine.customCommand(for: .draft(writablePaths: ["informes/"])), "leer \"$HIREBAR_PROMPT\"")
        XCTAssertEqual(back.aiEngine.customCommand(for: .act), "mi-ia \"$HIREBAR_PROMPT\"")
        XCTAssertEqual(back.aiEngine.displayName, "la IA")
    }

    func testOldSingleCustomCommandBecomesTheExecutionCommandOnly() throws {
        let json = #"{"aiEngine": {"kind": "custom", "customCommand": "mi-ia run"}}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        XCTAssertEqual(config.aiEngine.customCommand(for: .act), "mi-ia run")
        XCTAssertEqual(config.aiEngine.customCommand(for: .read), "")
    }

    func testEnvironmentJoinsRulesAndPromptAndCarriesThePhase() throws {
        let rules = FileManager.default.temporaryDirectory.appendingPathComponent("reglas-\(UUID().uuidString).md")
        try "Regla 1".write(to: rules, atomically: true, encoding: .utf8)
        let env = AIEngineSettings.environment(
            prompt: "Haz X", instructions: rules, profile: .draft(writablePaths: ["informes/", "perfil.json"]))
        XCTAssertEqual(env["HIREBAR_PROMPT"], "Haz X")
        XCTAssertEqual(env["HIREBAR_INSTRUCTIONS"], rules.path)
        XCTAssertEqual(env["HIREBAR_FULL_PROMPT"], "Regla 1\n\n---\n\nHaz X")
        XCTAssertEqual(env["HIREBAR_PHASE"], "draft")
        XCTAssertEqual(env["HIREBAR_WRITABLE_PATHS"], "informes/:perfil.json")
        XCTAssertEqual(AIEngineSettings.environment(prompt: "x", instructions: rules, profile: .read)["HIREBAR_PHASE"], "read")
    }
}
