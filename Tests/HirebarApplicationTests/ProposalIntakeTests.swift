import Foundation
import XCTest

@testable import HirebarApplication
@testable import HirebarDomain

final class ProposalIntakeTests: XCTestCase {
    let moment = Date(timeIntervalSince1970: 1_800_000_000)
    let window: TimeInterval = 30 * 86400

    func proposal(_ id: String, _ action: ActionKind, _ url: String) -> Proposal {
        Proposal(id: id, action: action, target: .url(url), title: id, source: "redes", text: action.requiresApprovedText ? "texto" : nil)
    }

    func testSocialFindingsBecomeAListAndActionsOutsideTheTaskAreRejected() {
        let found = [
            proposal("a", .apply, "https://linkedin.com/jobs/view/1"),
            proposal("b", .draftEmail, "https://linkedin.com/posts/2"),
            proposal("c", .sendEmail, "https://evil.example/x"),
        ]
        let result = ProposalIntake.accept(found, allowed: [.apply, .draftEmail], seen: [:], now: moment, window: window)
        XCTAssertEqual(result.fresh.map(\.id), ["a", "b"])
        XCTAssertEqual(result.rejected.map(\.id), ["c"])
    }

    func testFollowUpsAreProposedWithTheirTextAndNotRepeated() {
        let followUp = proposal("s1", .sendFollowUp, "https://www.workana.com/job/app/")
        let first = ProposalIntake.accept([followUp], allowed: [.sendFollowUp, .replyToClient], seen: [:], now: moment, window: window)
        XCTAssertEqual(first.fresh.first?.text, "texto")
        let again = ProposalIntake.accept(
            [proposal("s1", .sendFollowUp, "https://workana.com/job/app")], allowed: [.sendFollowUp], seen: first.seen,
            now: moment.addingTimeInterval(3600), window: window)
        XCTAssertTrue(again.fresh.isEmpty)
    }

    func testSeenTargetsExpireAfterTheWindow() {
        let seen = ["linkedin.com/jobs/view/1": moment.addingTimeInterval(-window - 1)]
        let result = ProposalIntake.accept(
            [proposal("a", .apply, "https://linkedin.com/jobs/view/1")], allowed: [.apply], seen: seen, now: moment, window: window)
        XCTAssertEqual(result.fresh.count, 1)
    }
}
