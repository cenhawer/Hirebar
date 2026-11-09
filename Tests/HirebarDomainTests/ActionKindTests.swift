import XCTest

@testable import HirebarDomain

final class ActionKindTests: XCTestCase {
    func testMessagesThePersonReadsBeforeApprovingRequireApprovedText() {
        XCTAssertEqual(
            Set(ActionKind.allCases.filter(\.requiresApprovedText)), [.sendEmail, .draftEmail, .sendFollowUp, .replyToClient])
    }

    func testPublishingAndClientRepliesAlwaysNeedApproval() {
        XCTAssertEqual(Set(ActionKind.allCases.filter(\.alwaysNeedsApproval)), [.publish, .replyToClient])
    }

    func testAutomaticSendingOnlyCoversMessagesToPreviousContacts() {
        XCTAssertEqual(Set(ActionKind.allCases.filter(\.requiresPriorContact)), [.sendFollowUp, .sendEmail])
    }
}
