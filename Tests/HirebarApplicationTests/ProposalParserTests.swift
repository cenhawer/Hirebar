import XCTest

@testable import HirebarApplication
@testable import HirebarDomain

final class ProposalParserTests: XCTestCase {
    func output(_ json: String) -> String {
        "Encontré dos vacantes.\nHIREBAR_PROPOSALS_BEGIN\n\(json)\nHIREBAR_PROPOSALS_END\n"
    }

    let validList = """
        {"schemaVersion": 1, "proposals": [
          {"id": "li:1", "action": "apply", "target": {"url": "https://linkedin.com/jobs/view/1"}, "title": "Backend", "source": "LinkedIn", "fit": "ENCAJA"},
          {"id": "s1", "action": "sendFollowUp", "target": {"url": "https://workana.com/job/x"}, "title": "API", "source": "Workana", "text": "Una idea nueva."}
        ]}
        """

    func testParsesTheLastBlockOfTheOutput() throws {
        let proposals = try ProposalParser.parse("HIREBAR_PROPOSALS_BEGIN {} HIREBAR_PROPOSALS_END " + output(validList)).get()
        XCTAssertEqual(proposals.map(\.id), ["li:1", "s1"])
        XCTAssertEqual(proposals.first?.fit, .strong)
    }

    func testMissingBlockFails() {
        XCTAssertEqual(ProposalParser.parse("SIN_NOVEDADES"), .failure(.blockMissing))
    }

    func testInvalidJsonFails() {
        XCTAssertEqual(ProposalParser.parse(output("{no es json")), .failure(.invalidJSON))
    }

    func testUnknownActionIsInvalid() {
        let item = #"{"id": "x", "action": "transfer", "target": {"url": "https://a.co"}, "title": "t", "source": "s"}"#
        let list = #"{"schemaVersion": 1, "proposals": [\#(item)]}"#
        XCTAssertEqual(ProposalParser.parse(output(list)), .failure(.invalidJSON))
    }

    func testUnsupportedVersionFails() {
        XCTAssertEqual(ProposalParser.parse(output(#"{"schemaVersion": 2, "proposals": []}"#)), .failure(.unsupportedVersion(2)))
    }

    func testActionThatSendsTextWithoutTextIsIncomplete() {
        let item = #"{"id": "n1", "action": "sendEmail", "target": {"email": "a@b.co"}, "title": "t", "source": "s"}"#
        let list = #"{"schemaVersion": 1, "proposals": [\#(item)]}"#
        XCTAssertEqual(ProposalParser.parse(output(list)), .failure(.incomplete(["n1"])))
    }

    func testDuplicateIdsFail() {
        let item = #"{"id": "d", "action": "apply", "target": {"url": "https://a.co"}, "title": "t", "source": "s"}"#
        let list = #"{"schemaVersion": 1, "proposals": [\#(item), \#(item)]}"#
        XCTAssertEqual(ProposalParser.parse(output(list)), .failure(.duplicateIds(["d"])))
    }

    func testRemovingBlockKeepsTheMessageForThePerson() {
        XCTAssertEqual(ProposalParser.removingBlock(from: output(validList)), "Encontré dos vacantes.")
    }
}
