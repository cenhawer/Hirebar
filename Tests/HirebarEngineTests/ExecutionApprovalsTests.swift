import Foundation
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import XCTest

@testable import HirebarEngine

final class ExecutionApprovalsTests: XCTestCase {
    var folder: URL!
    var rules: TargetRules!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        rules = try TargetRulesFile.load(from: EngineProfileTests.repositoryRoot.appendingPathComponent("Resources/destinos.json"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func pending(_ emails: String) throws -> URL {
        let file = folder.appendingPathComponent("pendientes.json")
        try Data(#"{"fecha": "2026-11-09", "correos": [\#(emails)]}"#.utf8).write(to: file)
        return file
    }

    func testEmailDraftsCarryTheRecipientSubjectAndTextThePersonWillSee() throws {
        let file = try pending(
            #"{"n": 1, "tipo": "empresa", "nombre": "Acme", "web": "acme.com", "correo": "Contacto@Acme.com", "#
                + #""asunto": "Hola", "cuerpo": "Texto"}, "#
                + #"{"n": 2, "tipo": "RESPUESTA", "nombre": "Beta", "correo": "ana@beta.co", "asunto": "Re: propuesta", "#
                + #""cuerpo": "Gracias"}"#
        )
        guard case .found(let drafts) = ExecutionApprovals.emailDrafts(rules: rules, pending: file) else {
            return XCTFail("debía leer los correos")
        }
        XCTAssertEqual(drafts.map(\.kind), ["EMPRESA", "RESPUESTA"])
        XCTAssertEqual(drafts[0].proposal.target, .email("Contacto@Acme.com"))
        XCTAssertEqual(drafts[0].proposal.title, "Hola")
        XCTAssertEqual(drafts[0].proposal.text, "Texto")
        XCTAssertEqual(drafts[0].proposal.source, "Acme (acme.com)")
        XCTAssertEqual(drafts[1].proposal.action, .replyToClient)
        let item = BatchItem(drafts[0].proposal, kind: drafts[0].kind)
        XCTAssertEqual(item.url, "Contacto@Acme.com")
        XCTAssertTrue(item.detail.contains("Texto"))
    }

    func testEmailListWithAnInvalidRecipientOrRepeatedNumberIsNotOffered() throws {
        let broken = try pending(
            #"{"n": 1, "tipo": "EMPRESA", "nombre": "Acme", "correo": "sin-arroba", "asunto": "Hola", "cuerpo": "Texto"}"#)
        guard case .invalid(let ids) = ExecutionApprovals.emailDrafts(rules: rules, pending: broken) else {
            return XCTFail("debía rechazarla")
        }
        XCTAssertEqual(ids, ["1"])
        let repeated = try pending(
            #"{"n": 3, "tipo": "EMPRESA", "nombre": "A", "correo": "a@a.co", "asunto": "x", "cuerpo": "y"}, "#
                + #"{"n": 3, "tipo": "EMPRESA", "nombre": "B", "correo": "b@b.co", "asunto": "x", "cuerpo": "y"}"#)
        guard case .invalid(let repeatedIds) = ExecutionApprovals.emailDrafts(rules: rules, pending: repeated) else {
            return XCTFail("debía rechazarla")
        }
        XCTAssertEqual(repeatedIds, ["3"])
    }

    func testWithoutPendingEmailsThereIsNothingToOffer() {
        guard case .none = ExecutionApprovals.emailDrafts(rules: rules, pending: folder.appendingPathComponent("nada.json")) else {
            return XCTFail("no debía haber correos")
        }
    }

    func testFollowUpsAreNeverRebuiltWithoutTheirApprovedText() {
        let item = BatchItem(
            Proposal(
                id: "s1", action: .sendFollowUp, target: .url("https://workana.com/job/app"), title: "App", source: "Workana", text: "x"))
        XCTAssertNil(ExecutionApprovals.proposal(from: item, mode: .followUpSend))
        XCTAssertEqual(ExecutionApprovals.proposal(from: item, mode: .freelance)?.action, .sendProposal)
    }

    func testBundledTargetRulesIgnoreTrackingButKeepIdentifyingParameters() {
        XCTAssertTrue(
            Target.url("https://linkedin.com/jobs/view/1?trk=x&utm_source=y").matches(
                .url("https://linkedin.com/jobs/view/1"), using: rules))
        XCTAssertFalse(Target.url("https://indeed.com/viewjob?jk=1").matches(.url("https://indeed.com/viewjob?jk=2"), using: rules))
        XCTAssertTrue(Target.account(network: "instagram", handle: "empresa").isValid(using: rules))
    }

    func testPausedNoticeSuggestsTheCommandThatWorksEvenWithARenamedAgent() {
        let pause = AgentPause(agent: AgentID(rawValue: "clientes"), batch: "b1", reason: "notApproved", since: Date())
        let controller = Controller(telegram: Telegram(secrets: NoTestSecrets()), stores: .files)
        XCTAssertTrue(controller.pausedNotice(.prospectingSend, pause).contains("reanudar clientes"))
    }
}
