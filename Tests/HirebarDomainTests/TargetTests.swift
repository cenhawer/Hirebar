import XCTest

@testable import HirebarDomain

final class TargetTests: XCTestCase {
    func testUrlsMatchIgnoringQueryFragmentSchemeWwwAndTrailingSlash() {
        let approved = Target.url("https://www.linkedin.com/jobs/view/4012/")
        XCTAssertTrue(approved.matches(.url("http://linkedin.com/jobs/view/4012?trk=public_jobs#apply")))
    }

    func testUrlsWithDifferentPathsDoNotMatch() {
        XCTAssertFalse(Target.url("https://www.workana.com/job/app-pagos").matches(.url("https://www.workana.com/job/otra")))
    }

    func testEmailsMatchIgnoringCaseAndSpaces() {
        XCTAssertTrue(Target.email("Contacto@Acme.com ").matches(.email("contacto@acme.com")))
        XCTAssertFalse(Target.email("contacto@acme.com").matches(.email("otro@ejemplo.com")))
    }

    func testAccountsMatchIgnoringAtSign() {
        XCTAssertTrue(Target.account(network: "instagram", handle: "@Empresa").matches(.account(network: "Instagram", handle: "empresa")))
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
}
