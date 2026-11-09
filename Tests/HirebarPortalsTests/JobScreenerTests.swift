import HirebarDomain
import XCTest

@testable import HirebarPortals

final class JobScreenerTests: XCTestCase {
    let profile = JobProfile.defaults

    func testRejectsEnglishRequirement() {
        let text = "Buscamos desarrollador backend con Node.js. Requisito: inglés avanzado. Trabajo remoto."
        XCTAssertEqual(JobScreener.screen(text, profile: profile), .reject("pide inglés alto"))
    }

    func testRejectsHybrid() {
        let text = "Desarrollador .NET para modalidad híbrida en Bogotá, 3 días en oficina."
        XCTAssertEqual(JobScreener.screen(text, profile: profile), .reject("híbrida o presencial"))
    }

    func testRejectsTooManyYears() {
        let text = "Desarrollador Java Spring Boot con 7 años de experiencia, 100% remoto."
        XCTAssertEqual(JobScreener.screen(text, profile: profile), .reject("pide 7+ años"))
    }

    func testKeepsRemoteNestJS() {
        let text = "Backend NestJS y TypeScript en AWS, trabajo 100% remoto desde Colombia, 3 años de experiencia."
        XCTAssertEqual(JobScreener.screen(text, location: "Colombia", profile: profile), .keep(.strong))
    }

    func testRejectsOtherCountryResidency() {
        let text = "Desarrollador Node.js remoto, solo residentes en Argentina."
        XCTAssertEqual(JobScreener.screen(text, profile: profile), .reject("remoto solo para argentina"))
    }

    func testClassifyTitles() {
        XCTAssertEqual(JobScreener.classify("Desarrollador Backend NestJS Senior", profile: profile), .strong)
        XCTAssertEqual(JobScreener.classify("Ingeniero DevOps", profile: profile), .stretch)
        XCTAssertNil(JobScreener.classify("Desarrollador PHP Laravel", profile: profile))
        XCTAssertNil(JobScreener.classify("Frontend React Developer", profile: profile))
    }

    func testSalary() {
        XCTAssertEqual(JobScreener.salaryCOP("$ 5.000.000,00"), 5_000_000)
        XCTAssertEqual(JobScreener.salaryCOP("$6 a $8 millones"), 8_000_000)
        XCTAssertTrue(JobScreener.lowPay("$ 3.500.000", profile: profile))
        XCTAssertFalse(JobScreener.lowPay("A convenir", profile: profile))
    }
}

final class FreelanceClassifierTests: XCTestCase {
    let profile = FreelanceProfile.defaults

    func testBackendProjectFits() {
        let fit = FreelanceClassifier.classify(head: "Desarrollo de API REST en Node.js con PostgreSQL",
                                               body: "Necesitamos una API para integrar nuestro sistema con la base de datos.",
                                               title: "Desarrollo de API REST en Node.js", profile: profile)
        XCTAssertEqual(fit, .strong)
    }

    func testChatbotTitleIsRejected() {
        let fit = FreelanceClassifier.classify(head: "Chatbot con IA para WhatsApp", body: "Bot con API de WhatsApp y webhook",
                                               title: "Chatbot con IA para WhatsApp", profile: profile)
        XCTAssertNil(fit)
    }

    func testWordPressIsBlocked() {
        let fit = FreelanceClassifier.classify(head: "Sitio en WordPress con API", body: "Integrar API REST", profile: profile)
        XCTAssertNil(fit)
    }

    func testEnglishIsRejected() {
        XCTAssertTrue(FreelanceClassifier.looksEnglish("We need a backend developer for our API and the database"))
    }
}

final class WorkanaParsingTests: XCTestCase {
    func testResultsFromHTML() {
        let html = #"<div :results-initials='{"results":[{"slug":"api-node","title":"API Node"}]}'></div>"#
        let results = WorkanaSource.results(html)
        XCTAssertEqual(results.first?["slug"] as? String, "api-node")
    }
}
