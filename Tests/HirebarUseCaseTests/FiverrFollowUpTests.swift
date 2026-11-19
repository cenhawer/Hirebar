import Foundation
import HirebarDomain
import HirebarPortals
import HirebarStorage
import XCTest

@testable import HirebarApplication

@MainActor
final class FiverrFollowUpTests: XCTestCase {
    nonisolated static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-fiverr-\(UUID().uuidString)")
    var controller: Controller!

    override static func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override static func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    override func setUp() async throws {
        try? FileManager.default.removeItem(at: Self.home)
        Paths.ensure()
        controller = Controller.forTests()
    }

    func setFiverr(_ on: Bool) {
        var config = Config()
        config.setEnabled(Config.fiverr, on)
        config.save()
    }

    func prompt(_ mode: Mode) -> String {
        let batch = Batch(mode: mode, status: .pending)
        return controller.prompts.prompt(for: batch, items: [], owner: "Ana")
    }

    func testFiverrIsAFreelanceSourceThatStartsOn() {
        XCTAssertTrue(Config.freelanceSources.contains(Config.fiverr))
        XCTAssertTrue(Config().isEnabled(Config.fiverr))
        XCTAssertFalse(PortalAccess.bundled.freelance.map(\.id).contains(Config.fiverr))
    }

    func testWithFiverrOnTheFollowUpReviewAlsoReadsFiverr() {
        setFiverr(true)
        let text = prompt(.followUp)
        XCTAssertTrue(text.contains("Revisa también Fiverr solo para leer y avisar (punto 5"))
        XCTAssertFalse(text.contains("Fiverr está apagado"))
        XCTAssertEqual(Config.load().fiverrStatus, "Fiverr: mensajes y pedidos en los seguimientos")
    }

    func testWithFiverrOffTheFollowUpReviewSkipsIt() {
        setFiverr(false)
        let text = prompt(.followUp)
        XCTAssertTrue(text.contains("Fiverr está apagado en Hirebar: salta el punto 5"))
        XCTAssertEqual(Config.load().fiverrStatus, "Fiverr: apagado")
    }

    func testFiverrIsOnlyReadInTheReviewTaskThatCannotAct() {
        XCTAssertFalse(TaskProfiles.profile(for: .followUp, account: nil).canAct)
        setFiverr(true)
        XCTAssertFalse(prompt(.followUpSend).contains("Fiverr"))
    }

    func testTheProposalRulesLiveInTheFreelanceInstructionsAndNotInThePrompt() throws {
        let rules = try String(
            contentsOf: RuleContractTests.folder.appendingPathComponent("instrucciones-freelance.md"), encoding: .utf8)
        XCTAssertTrue(rules.contains("Cliente sin pago verificado"))
        XCTAssertTrue(rules.contains("Proyectos con IA: SÍ si el núcleo es backend"))
        XCTAssertTrue(rules.contains("Páginas web y landings"))
        let text = prompt(.freelance)
        XCTAssertFalse(text.contains("Reglas vigentes"))
        XCTAssertFalse(text.contains("Cliente sin pago verificado"))
    }

    func testTheFollowUpRulesDescribeAReadOnlyFiverrReview() throws {
        let rules = try String(
            contentsOf: RuleContractTests.folder.appendingPathComponent("instrucciones-seguimiento.md"), encoding: .utf8)
        XCTAssertTrue(rules.contains("5. Fiverr"))
        XCTAssertTrue(rules.contains("En Fiverr solo lees y avisas"))
        XCTAssertTrue(rules.contains("no pongas nada de Fiverr en la lista de propuestas"))
        XCTAssertTrue(rules.contains("sección `fiverr`"))
    }

    func testTheFreelanceRadarListsUpToTheConfiguredNumberOfProjects() {
        XCTAssertEqual(Controller.repositoryPolicy.radares.freelance.proyectosPorLista, 8)
        XCTAssertEqual(AgentSettings.defaults(for: .freelance).dailyLimit, 12)
    }
}
