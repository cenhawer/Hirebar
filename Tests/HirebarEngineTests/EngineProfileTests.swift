import Foundation
import HirebarApplication
import HirebarCore
import XCTest

@testable import HirebarEngine

final class EngineProfileTests: XCTestCase {
    static let repositoryRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    static let actingBrowserTools = [
        "computer", "form_input", "javascript_tool", "file_upload", "upload_image", "shortcuts_execute",
        "browser_batch",
    ]

    var profiles: EngineProfiles!
    let playbook = URL(fileURLWithPath: "/tmp/instrucciones-redes.md")

    override func setUpWithError() throws {
        profiles = try EngineProfiles.load(from: Self.repositoryRoot.appendingPathComponent("Resources/perfiles-ia.json"))
    }

    func claudeArguments(_ profile: RunProfile, browser: Bool = true) -> [String] {
        ClaudeCLI.arguments(prompt: "pedido", playbook: playbook, profile: profile, browser: browser, settings: profiles.claude)
    }

    func values(after flag: String, in arguments: [String]) -> [String] {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return [] }
        return arguments[index + 1].split(separator: ",").map(String.init)
    }

    func testReadProfileCannotWriteActOrBypassPermissions() {
        let arguments = claudeArguments(.read)
        XCTAssertEqual(values(after: "--permission-mode", in: arguments), ["dontAsk"])
        XCTAssertTrue(arguments.contains("--restricted"))
        XCTAssertFalse(arguments.joined(separator: " ").contains("bypassPermissions"))
        let tools = values(after: "--tools", in: arguments)
        let allowed = values(after: "--allowedTools", in: arguments)
        XCTAssertTrue(Set(tools + allowed).isDisjoint(with: ["Write", "Edit", "Bash"]))
        for tool in Self.actingBrowserTools {
            XCTAssertFalse(allowed.contains("mcp__claude-in-chrome__\(tool)"), tool)
        }
        XCTAssertFalse(allowed.contains("mcp__claude-in-chrome"))
        XCTAssertTrue(allowed.contains("mcp__claude-in-chrome__read_page"))
    }

    func testReadProfileCannotReadPersonalFiles() {
        let denied = values(after: "--disallowedTools", in: claudeArguments(.read))
        XCTAssertEqual(Set(denied), ["Read(./perfil.json)", "Read(./perfil.md)", "Read(./hv/**)"])
    }

    func testWithoutBrowserNoBrowserToolIsAllowed() {
        let arguments = claudeArguments(.read, browser: false)
        XCTAssertFalse(arguments.contains("--chrome"))
        XCTAssertFalse(values(after: "--allowedTools", in: arguments).contains { $0.hasPrefix("mcp__") })
    }

    func testDraftProfileWritesOnlyInItsDeclaredPaths() {
        let allowed = values(after: "--allowedTools", in: claudeArguments(.draft(writablePaths: ["informes/"])))
        XCTAssertTrue(allowed.contains("Write(./informes/**)"))
        XCTAssertTrue(allowed.contains("Edit(./informes/**)"))
        XCTAssertFalse(allowed.contains("Write"))
        XCTAssertFalse(allowed.contains("Edit"))
        XCTAssertFalse(allowed.contains("mcp__claude-in-chrome__computer"))
    }

    func testDraftProfileThatUpdatesTheProfileCanReadIt() {
        let arguments = claudeArguments(.draft(writablePaths: ["perfil.json", "perfil.md", "hv/"]), browser: false)
        XCTAssertFalse(arguments.contains("--disallowedTools"))
        XCTAssertTrue(values(after: "--allowedTools", in: arguments).contains("Write(./perfil.json)"))
    }

    func testActProfileCanUseTheBrowserAndWriteButNotBypassPermissions() {
        let arguments = claudeArguments(.act)
        let allowed = values(after: "--allowedTools", in: arguments)
        XCTAssertTrue(allowed.contains("Write"))
        XCTAssertTrue(allowed.contains("mcp__claude-in-chrome"))
        XCTAssertTrue(arguments.contains("--restricted"))
        XCTAssertEqual(values(after: "--permission-mode", in: arguments), ["dontAsk"])
        XCTAssertFalse(arguments.contains("--disallowedTools"))
    }

    func testCodexAndGeminiReadWithoutPermissionToAct() {
        XCTAssertTrue(profiles.codex.command(.read).contains("--sandbox read-only"))
        XCTAssertTrue(profiles.gemini.command(.read).contains("--approval-mode default"))
        XCTAssertFalse(profiles.gemini.command(.read).contains("yolo"))
    }

    func testCodexAndGeminiDoNotRunTasksThatReadWithTheBrowser() {
        for kind in [AIEngineKind.codex, .gemini] {
            let reading = launch(AIEngineSettings(kind: kind), profile: .read, browser: true)
            XCTAssertNil(try? reading.get(), kind.rawValue)
            let acting = launch(AIEngineSettings(kind: kind), profile: .act, browser: true)
            XCTAssertNotNil(try? acting.get(), kind.rawValue)
            let readingWithoutBrowser = launch(AIEngineSettings(kind: kind), profile: .read, browser: false)
            XCTAssertNotNil(try? readingWithoutBrowser.get(), kind.rawValue)
        }
    }

    func testCustomEngineUsesTheCommandOfEachPhaseAndTellsWhichOneIsMissing() {
        let engine = AIEngineSettings(kind: .custom, readCommand: "", actCommand: "mi-ia act")
        guard case .failure(let problem) = launch(engine, profile: .read, browser: false) else { return XCTFail("debía fallar") }
        XCTAssertTrue(problem.message.contains("de lectura"))
        guard case .success(.shell(let command, let environment)) = launch(engine, profile: .act, browser: true) else {
            return XCTFail("debía lanzar el comando de ejecución")
        }
        XCTAssertEqual(command, "mi-ia act")
        XCTAssertEqual(environment["HIREBAR_PHASE"], "act")
    }

    func launch(_ engine: AIEngineSettings, profile: RunProfile, browser: Bool) -> Result<ClaudeCLI.Launch, ClaudeCLI.LaunchProblem> {
        ClaudeCLI.launch(
            engine: engine,
            request: ClaudeCLI.LaunchRequest(prompt: "p", playbook: playbook, profile: profile, browser: browser),
            profiles: profiles,
            claudePath: { "/usr/local/bin/claude" })
    }

    func testEachTaskGetsItsProfile() {
        XCTAssertEqual(TaskProfiles.profile(for: .social, account: nil), .read)
        XCTAssertEqual(TaskProfiles.profile(for: .portalScanJobs, account: nil), .read)
        XCTAssertEqual(TaskProfiles.profile(for: .followUp, account: nil), .draft(writablePaths: ["seguimiento.json"]))
        XCTAssertEqual(TaskProfiles.profile(for: .weeklyReport, account: nil), .draft(writablePaths: ["informes/"]))
        XCTAssertEqual(
            TaskProfiles.profile(for: .linkedInDraft, account: ContentAccount(id: "empresa")),
            .draft(writablePaths: ["contenido/empresa/"]))
        for mode in [Mode.jobs, .freelance, .prospectingSend, .linkedInPublish] {
            XCTAssertEqual(TaskProfiles.profile(for: mode, account: nil), .act, mode.rawValue)
        }
        XCTAssertFalse(TaskProfiles.needsBrowser(.weeklyReport, account: nil))
        XCTAssertFalse(TaskProfiles.needsBrowser(.profileUpdate, account: nil))
    }
}
