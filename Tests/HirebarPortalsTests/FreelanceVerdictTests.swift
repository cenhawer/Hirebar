import Foundation
import HirebarApplication
import XCTest

@testable import HirebarDomain
@testable import HirebarPortals

final class FreelanceVerdictTests: XCTestCase {
    let profile = RepositoryDefaults.searchProfile.freelance

    func verdict(_ title: String, _ body: String) -> (fit: Fit?, reason: FreelanceDiscard?) {
        FreelanceClassifier.verdict(head: title, body: body, title: title, profile: profile)
    }

    func testAnAIProjectWithoutABackendCoreIsDiscardedWithItsReason() {
        let result = verdict("Agente de IA para responder preguntas", "Queremos un asistente que conteste a nuestros usuarios.")
        XCTAssertNil(result.fit)
        XCTAssertEqual(result.reason, .aiWithoutBackend("ia"))
        XCTAssertEqual(result.reason?.text, "IA sin backend (ia)")
    }

    func testAnAIProjectWhoseCoreIsBackendPasses() {
        let result = verdict(
            "Integración de OpenAI con API REST en Node.js",
            "Backend con PostgreSQL que llama a la API de OpenAI y guarda en la base de datos.")
        XCTAssertNotNil(result.fit)
        XCTAssertNil(result.reason)
    }

    func testLandingPagesAndExcelToSystemProjectsAreNoLongerBlocked() {
        XCTAssertEqual(
            verdict("Landing page en Angular con HTML y CSS", "Formulario conectado a una API para registrar clientes.").fit, .stretch)
        XCTAssertEqual(
            verdict("Migrar Excel a un sistema con base de datos", "Pasar el control de inventario a una aplicación.").fit, .stretch)
    }

    func testTheDefaultFreelanceProfileIsLoosened() {
        for word in ["ia", "inteligencia artificial", "gpt", "chatgpt", "openai", "llm", "firebase", "landing", "pagina web", "sitio web"] {
            XCTAssertFalse(profile.titleNever.contains(word), word)
        }
        for word in ["research", "investigacion", "catalog", "catalogo", "excel"] {
            XCTAssertFalse(profile.offProfile.contains(word), word)
        }
        for word in ["pagina web", "sitio web", "landing", "landing page", "html", "css", "excel"] {
            XCTAssertTrue(profile.stretch.contains(word), word)
        }
        XCTAssertTrue(profile.aiWords.contains("inteligencia artificial"))
        XCTAssertEqual(profile.portals.workanaMaxAgeMinutes, 1440)
    }

    func testClassifyReturnsTheSameFitAsTheVerdict() {
        let cases = [
            ("Desarrollo de API REST en Node.js", "Necesitamos una API para integrar nuestro sistema con la base de datos."),
            ("Sitio en WordPress con API", "Integrar API REST"),
            ("Logo para mi marca", "Diseño de identidad"),
        ]
        for (title, body) in cases {
            XCTAssertEqual(FreelanceClassifier.classify(head: title, body: body, title: title, profile: profile), verdict(title, body).fit)
        }
        XCTAssertEqual(verdict("Sitio en WordPress con API", "Integrar API REST").reason, .blockedWord("wordpress"))
        XCTAssertEqual(
            verdict("We need a backend developer", "We are looking for the best developer and you will work with our team").reason, .english
        )
        XCTAssertEqual(verdict("Ayuda con un proyecto", "Necesito ayuda pronto").reason, .noStackWords)
    }

    func testTheSummaryGroupsReasonsMostFrequentFirstWithAnExample() {
        let notes = [
            FreelanceDiscardNote(reason: .budgetTooLow, title: "Tienda barata"),
            FreelanceDiscardNote(reason: .english, title: "Backend developer"),
            FreelanceDiscardNote(reason: .english, title: "Mobile app"),
            FreelanceDiscardNote(reason: .budgetTooLow, title: "Bot sencillo"),
            FreelanceDiscardNote(reason: .english, title: "Data entry"),
            FreelanceDiscardNote(reason: .titleWord("bot"), title: "Chatbot de ventas"),
        ]
        XCTAssertEqual(
            FreelanceClassifier.summary(notes),
            "en inglés 3 (ej: Backend developer); presupuesto muy bajo 2 (ej: Tienda barata); título con \"bot\" 1 (ej: Chatbot de ventas)")
        XCTAssertEqual(FreelanceClassifier.summary([]), "")
    }

    func testTheSummaryKeepsOnlyTheMostCommonReasonsAndShortExamples() {
        let reasons: [FreelanceDiscard] = [
            .english, .whatsappBot, .preferredOrPrivate, .hourlyTooLow, .budgetTooLow, .noStackWords, .asksFor("php"),
        ]
        let long = String(repeating: "a", count: 80)
        let summary = FreelanceClassifier.summary(reasons.map { FreelanceDiscardNote(reason: $0, title: long) })
        XCTAssertEqual(summary.components(separatedBy: "; ").count, FreelanceClassifier.summaryReasons)
        XCTAssertFalse(summary.contains(long))
    }
}

final class FreelanceDiscardCollectionTests: XCTestCase {
    func testFreelancerCollectsWhyEachProjectWasDiscarded() async {
        let source = FreelancerSource(
            fetcher: FixtureFetcher(routes: ["projects/active": "freelancer-proyectos.json"]), now: { PortalFixtureTests.capturedAt })
        let found = await source.search(skip: [], profile: RepositoryDefaults.searchProfile)
        XCTAssertTrue(found.discarded.contains { $0.reason == .preferredOrPrivate })
        XCTAssertFalse(found.discarded.isEmpty)
        XCTAssertFalse(FreelanceClassifier.summary(found.discarded).isEmpty)
        let hitTitles = Set(found.hits.map(\.title))
        XCTAssertTrue(found.discarded.allSatisfy { !hitTitles.contains($0.title) })
    }

    func testWorkanaCollectsWhyEachProjectWasDiscarded() async {
        let source = WorkanaSource(
            fetcher: FixtureFetcher(routes: ["/jobs?": "workana-busqueda.html", "/job/": "workana-proyecto.html"]))
        var profile = RepositoryDefaults.searchProfile
        profile.freelance.portals.workanaMaxAgeMinutes = Int.max
        let found = await source.search(skip: [], profile: profile)
        XCTAssertFalse(found.discarded.isEmpty)
    }
}
