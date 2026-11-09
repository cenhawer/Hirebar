import XCTest

@testable import HirebarDomain

final class TargetTests: XCTestCase {
    let rules = TargetRules(
        ignoredQueryParameters: ["trk", "refId"], ignoredQueryParameterPrefixes: ["utm_"], networks: ["linkedin", "instagram"],
        webSchemes: ["https", "http"])

    func testUrlsMatchIgnoringTrackingParametersFragmentSchemeWwwAndTrailingSlash() {
        let approved = Target.url("https://www.linkedin.com/jobs/view/4012/")
        XCTAssertTrue(approved.matches(.url("http://linkedin.com/jobs/view/4012?trk=public_jobs&utm_source=x#apply"), using: rules))
    }

    func testUrlsThatIdentifyTheVacancyInTheQueryDoNotMatchAnotherVacancy() {
        let approved = Target.url("https://www.indeed.com/viewjob?jk=APROBADA&from=serp")
        XCTAssertFalse(approved.matches(.url("https://indeed.com/viewjob?jk=OTRA&from=serp"), using: rules))
        XCTAssertTrue(approved.matches(.url("https://indeed.com/viewjob?from=serp&jk=APROBADA&utm_medium=mail"), using: rules))
    }

    func testUrlWithoutSchemeMatchesTheSameAddressWithScheme() {
        XCTAssertTrue(Target.url("www.workana.com/job/app").matches(.url("https://workana.com/job/app/"), using: rules))
    }

    func testRouteFragmentsAreKept() {
        XCTAssertFalse(Target.url("https://portal.co/#/vacantes/1").matches(.url("https://portal.co/#/vacantes/2"), using: rules))
    }

    func testUrlsWithDifferentPathsDoNotMatch() {
        XCTAssertFalse(
            Target.url("https://www.workana.com/job/app-pagos").matches(.url("https://www.workana.com/job/otra"), using: rules))
    }

    func testEmailsMatchIgnoringCaseAndSpaces() {
        XCTAssertTrue(Target.email("Contacto@Acme.com ").matches(.email("contacto@acme.com"), using: rules))
        XCTAssertFalse(Target.email("contacto@acme.com").matches(.email("otro@ejemplo.com"), using: rules))
    }

    func testAccountsMatchIgnoringAtSign() {
        XCTAssertTrue(
            Target.account(network: "instagram", handle: "@Empresa").matches(
                .account(network: "Instagram", handle: "empresa"), using: rules))
    }

    func testOnlyWellFormedTargetsAreValid() {
        XCTAssertTrue(Target.url("https://linkedin.com/jobs/view/1").isValid(using: rules))
        XCTAssertTrue(Target.url("workana.com/job/app").isValid(using: rules))
        XCTAssertFalse(Target.url("").isValid(using: rules))
        XCTAssertFalse(Target.url("ftp://archivos.co/x").isValid(using: rules))
        XCTAssertFalse(Target.url("no es un enlace").isValid(using: rules))
        XCTAssertTrue(Target.email("contacto@acme.com").isValid(using: rules))
        XCTAssertFalse(Target.email("contacto").isValid(using: rules))
        XCTAssertFalse(Target.email("a@b").isValid(using: rules))
        XCTAssertTrue(Target.account(network: "LinkedIn", handle: "@yo").isValid(using: rules))
        XCTAssertFalse(Target.account(network: "tiktok", handle: "yo").isValid(using: rules))
        XCTAssertFalse(Target.account(network: "linkedin", handle: " ").isValid(using: rules))
    }

    func testDecodesEachSchemaShape() throws {
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(Target.self, from: Data(#"{"url":"https://a.co/x"}"#.utf8)), .url("https://a.co/x"))
        XCTAssertEqual(try decoder.decode(Target.self, from: Data(#"{"email":"a@b.co"}"#.utf8)), .email("a@b.co"))
        XCTAssertEqual(
            try decoder.decode(Target.self, from: Data(#"{"network":"linkedin","handle":"yo"}"#.utf8)),
            .account(network: "linkedin", handle: "yo")
        )
    }

    func testTargetWithMoreThanOneShapeIsRejected() {
        XCTAssertThrowsError(try JSONDecoder().decode(Target.self, from: Data(#"{"url":"https://a.co","email":"a@b.co"}"#.utf8)))
    }
}
