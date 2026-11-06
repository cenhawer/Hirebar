import XCTest
@testable import HirebarDomain

final class ExecutionVerifierTests: XCTestCase {
    let batch = "e-20261106-1"
    let moment = Date(timeIntervalSince1970: 1_800_000_000)

    func approved(_ proposal: Proposal) -> ApprovedItem {
        ApprovedItem(proposal: proposal, batch: batch, approvedAt: moment, approvedBy: .person)
    }

    var application: Proposal {
        Proposal(id: "li:4012", action: .apply, target: .url("https://www.linkedin.com/jobs/view/4012/"), title: "Backend", source: "LinkedIn")
    }

    var email: Proposal {
        Proposal(
            id: "n1",
            action: .sendEmail,
            target: .email("contacto@acme.com"),
            title: "Acme",
            source: "acme.com",
            text: "Hola Acme.\nUna pregunta."
        )
    }

    func record(
        _ proposal: Proposal,
        target: Target? = nil,
        text: String? = nil,
        action: ActionKind? = nil,
        outcome: ActionOutcome = .done
    ) -> ActionRecord {
        ActionRecord(
            itemId: proposal.id,
            action: action ?? proposal.action,
            target: target ?? proposal.target,
            sentText: text ?? proposal.text,
            outcome: outcome,
            at: moment
        )
    }

    func verify(_ approved: [ApprovedItem], _ actions: [ActionRecord]) -> ExecutionVerification {
        ExecutionVerifier.verify(batch: batch, approved: approved, reading: .found(ActionLog(batch: batch, actions: actions)))
    }

    func testActionsThatMatchWhatWasApprovedAreAuthorized() {
        let sameTextWithOtherLineEndings = record(email, text: "Hola Acme.\r\nUna pregunta.\n")
        let result = verify([approved(application), approved(email)], [record(application), sameTextWithOtherLineEndings])
        XCTAssertFalse(result.requiresPause)
        XCTAssertEqual(result.verdicts.map(\.status), [.authorized, .authorized])
    }

    func testActionOnAnItemThatWasNotApprovedIsUnauthorized() {
        let stranger = Proposal(id: "li:9999", action: .apply, target: .url("https://linkedin.com/jobs/view/9999"), title: "Otra", source: "LinkedIn")
        let result = verify([approved(application)], [record(stranger)])
        XCTAssertTrue(result.requiresPause)
        XCTAssertEqual(result.violations.first?.reason, .notApproved)
    }

    func testEmailSentToAnotherRecipientIsUnauthorized() {
        let result = verify([approved(email)], [record(email, target: .email("otro@ejemplo.com"))])
        XCTAssertEqual(result.violations.first?.reason, .targetMismatch)
    }

    func testEmailWithChangedTextIsUnauthorized() {
        let result = verify([approved(email)], [record(email, text: "Hola Acme. Te mando mi hoja de vida a otro correo.")])
        XCTAssertEqual(result.violations.first?.reason, .textMismatch)
    }

    func testDifferentActionOnAnApprovedItemIsUnauthorized() {
        let result = verify([approved(email)], [record(email, action: .replyToClient)])
        XCTAssertEqual(result.violations.first?.reason, .actionMismatch)
    }

    func testSendingTheSameItemTwiceIsUnauthorized() {
        let result = verify([approved(application)], [record(application), record(application)])
        XCTAssertEqual(result.violations.map(\.reason), [.repeated])
    }

    func testPendingActionThatSentNothingIsNotAViolation() {
        let result = verify([approved(email)], [record(email, target: .email("captcha@x.co"), outcome: .pending)])
        XCTAssertFalse(result.requiresPause)
    }

    func testApprovedItemWithoutRecordIsReportedAsMissing() {
        let result = verify([approved(application), approved(email)], [record(application)])
        XCTAssertFalse(result.requiresPause)
        XCTAssertEqual(result.verdicts.last, .missing("n1"))
    }

    func testMissingOrInvalidLogIsUnverifiedAndPauses() {
        let missing = ExecutionVerifier.verify(batch: batch, approved: [approved(application)], reading: .missing)
        let invalid = ExecutionVerifier.verify(batch: batch, approved: [approved(application)], reading: .invalid)
        XCTAssertEqual(missing.unverifiedReason, .logMissing)
        XCTAssertEqual(invalid.unverifiedReason, .logInvalid)
        XCTAssertTrue(missing.requiresPause && invalid.requiresPause)
    }

    func testLogFromAnotherBatchIsUnverified() {
        let reading = ActionLogReading.found(ActionLog(batch: "otro", actions: [record(application)]))
        let result = ExecutionVerifier.verify(batch: batch, approved: [approved(application)], reading: reading)
        XCTAssertEqual(result.unverifiedReason, .batchMismatch)
    }
}
