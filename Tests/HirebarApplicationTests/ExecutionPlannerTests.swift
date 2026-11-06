import XCTest
@testable import HirebarApplication
@testable import HirebarDomain

final class ExecutionPlannerTests: XCTestCase {
    func items(_ count: Int) -> [ApprovedItem] {
        (1...count).map {
            ApprovedItem(
                proposal: Proposal(id: "p\($0)", action: .apply, target: .url("https://a.co/\($0)"), title: "t", source: "s"),
                batch: "b",
                approvedAt: Date(timeIntervalSince1970: 0),
                approvedBy: .person
            )
        }
    }

    func testWithoutQuotaEverythingRunsNow() {
        let plan = ExecutionPlanner.plan(items(3), remainingQuota: nil)
        XCTAssertEqual(plan.now.count, 3)
        XCTAssertTrue(plan.deferred.isEmpty)
    }

    func testOnlyWhatFitsInTheRemainingQuotaRuns() {
        let plan = ExecutionPlanner.plan(items(5), remainingQuota: 2)
        XCTAssertEqual(plan.now.map(\.proposal.id), ["p1", "p2"])
        XCTAssertEqual(plan.deferred.map(\.proposal.id), ["p3", "p4", "p5"])
    }

    func testExhaustedQuotaDefersEverything() {
        XCTAssertTrue(ExecutionPlanner.plan(items(2), remainingQuota: 0).now.isEmpty)
        XCTAssertTrue(ExecutionPlanner.plan(items(2), remainingQuota: -1).now.isEmpty)
    }
}
