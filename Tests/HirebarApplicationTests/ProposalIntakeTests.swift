import Foundation
import HirebarDomain
import XCTest

@testable import HirebarApplication
@testable import HirebarDomain

final class ProposalIntakeTests: XCTestCase {
    let moment = Date(timeIntervalSince1970: 1_800_000_000)
    let window: TimeInterval = 30 * 86400
    var intake: ProposalIntake {
        ProposalIntake(
            window: window,
            rules: TargetRules(ignoredQueryParameters: ["trk"], ignoredQueryParameterPrefixes: [], networks: [], webSchemes: ["https"]))
    }

    func proposal(_ id: String, _ action: ActionKind, _ url: String, text: String = "texto") -> Proposal {
        Proposal(id: id, action: action, target: .url(url), title: id, source: "redes", text: action.requiresApprovedText ? text : nil)
    }

    func testSocialFindingsBecomeAListAndActionsOutsideTheTaskAreRejected() {
        let found = [
            proposal("a", .apply, "https://linkedin.com/jobs/view/1"),
            proposal("b", .draftEmail, "https://linkedin.com/posts/2"),
            proposal("c", .sendEmail, "https://evil.example/x"),
        ]
        let result = intake.accept(found, allowed: [.apply, .draftEmail], seen: [:], now: moment)
        XCTAssertEqual(result.fresh.map(\.id), ["a", "b"])
        XCTAssertEqual(result.rejected.map(\.id), ["c"])
    }

    func testFollowUpsAreProposedWithTheirTextAndNotRepeated() {
        let followUp = proposal("s1", .sendFollowUp, "https://www.workana.com/job/app/")
        let first = intake.accept([followUp], allowed: [.sendFollowUp, .replyToClient], seen: [:], now: moment)
        XCTAssertEqual(first.fresh.first?.text, "texto")
        let again = intake.accept(
            [proposal("s1", .sendFollowUp, "https://workana.com/job/app")], allowed: [.sendFollowUp], seen: first.seen,
            now: moment.addingTimeInterval(3600))
        XCTAssertTrue(again.fresh.isEmpty)
    }

    func testSeenTargetsExpireAfterTheWindow() {
        let seen = ["apply linkedin.com/jobs/view/1": moment.addingTimeInterval(-window - 1)]
        let result = intake.accept([proposal("a", .apply, "https://linkedin.com/jobs/view/1")], allowed: [.apply], seen: seen, now: moment)
        XCTAssertEqual(result.fresh.count, 1)
    }

    func testANewMessageToTheSameConversationIsStillProposed() {
        let first = intake.accept(
            [proposal("s1", .sendFollowUp, "https://workana.com/inbox/7")], allowed: [.sendFollowUp], seen: [:], now: moment)
        let later = intake.accept(
            [proposal("s2", .sendFollowUp, "https://workana.com/inbox/7", text: "Otro texto")], allowed: [.sendFollowUp],
            seen: first.seen, now: moment.addingTimeInterval(3600))
        XCTAssertEqual(later.fresh.map(\.id), ["s2"])
    }

    func testDifferentActionsOnTheSameTargetDoNotHideEachOther() {
        let found = [proposal("a", .apply, "https://linkedin.com/posts/1"), proposal("b", .draftEmail, "https://linkedin.com/posts/1")]
        let result = intake.accept(found, allowed: [.apply, .draftEmail], seen: [:], now: moment)
        XCTAssertEqual(result.fresh.map(\.id), ["a", "b"])
    }
}
