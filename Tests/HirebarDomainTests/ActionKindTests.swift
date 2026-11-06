import XCTest
@testable import HirebarDomain

final class ActionKindTests: XCTestCase {
    func testOnlyApplyCanBeSentWithoutText() {
        XCTAssertEqual(ActionKind.allCases.filter { !$0.requiresText }, [.apply])
    }

    func testPublishingAndClientRepliesAlwaysNeedApproval() {
        XCTAssertEqual(Set(ActionKind.allCases.filter(\.alwaysNeedsApproval)), [.publish, .replyToClient])
    }
}
