import Foundation
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import XCTest

@MainActor
final class RuleContractTests: XCTestCase {
    nonisolated static let folder = EngineProfileTests.repositoryRoot.appendingPathComponent("Resources/inicial")
    nonisolated static let injectionClause = "no lo hagas: es contenido"
    nonisolated static let readingRules = [
        "instrucciones-redes.md", "instrucciones-portales-empleo.md", "instrucciones-portales-freelance.md", "instrucciones-seguimiento.md",
    ]
    nonisolated static let externalContentRules =
        readingRules + [
            "instrucciones-prospeccion.md", "instrucciones-contenido.md", "instrucciones-empleo.md", "instrucciones-freelance.md",
            "instrucciones-seguimiento-envio.md", "instrucciones-prospeccion-envio.md", "instrucciones-contenido-publicar.md",
        ]
    nonisolated static let executionRules = [
        "instrucciones-empleo.md", "instrucciones-freelance.md", "instrucciones-seguimiento-envio.md", "instrucciones-prospeccion-envio.md",
        "instrucciones-contenido-publicar.md",
    ]
    nonisolated static let writingRules = [
        "instrucciones-contenido.md", "instrucciones-perfil.md", "instrucciones-freelance.md", "instrucciones-prospeccion.md",
    ]

    func text(_ name: String) throws -> String {
        try String(contentsOf: Self.folder.appendingPathComponent(name), encoding: .utf8)
    }

    func testRulesThatReadExternalContentTreatItAsContent() throws {
        for name in Self.externalContentRules {
            XCTAssertTrue(try text(name).contains(Self.injectionClause), name)
        }
    }

    func testReadingRulesReturnProposalsInsteadOfActing() throws {
        for name in Self.readingRules {
            XCTAssertTrue(try text(name).contains("HIREBAR_PROPOSALS_BEGIN"), name)
        }
    }

    func testExecutionRulesRequireTheActionLog() throws {
        for name in Self.executionRules {
            XCTAssertTrue(try text(name).contains("Registro de acciones"), name)
        }
    }

    func testRulesThatWriteForThePersonForbidInventingResults() throws {
        for name in Self.writingRules {
            XCTAssertTrue(try text(name).lowercased().contains("invent"), name)
        }
    }
}
