import Foundation
import XCTest

@testable import HirebarApplication
@testable import HirebarDomain

final class InMemoryExecutionStateStore: ExecutionStateStore, @unchecked Sendable {
    var storedProposals: [String: [Proposal]] = [:]
    var approved: [String: [ApprovedItem]] = [:]
    var logs: [String: ActionLogReading] = [:]
    var verifications: [(AgentID, ExecutionVerification)] = []
    var activePauses: [AgentPause] = []
    var completedToday = 0

    func proposals(batch: String) -> [Proposal] { storedProposals[batch] ?? [] }
    func saveProposals(_ proposals: [Proposal], batch: String) throws { storedProposals[batch] = proposals }
    func approvedItems(batch: String) -> [ApprovedItem] { approved[batch] ?? [] }
    func saveApproved(_ items: [ApprovedItem], batch: String) throws { approved[batch] = items }
    func actionLog(batch: String) -> ActionLogReading { logs[batch] ?? .missing }
    func save(_ verification: ExecutionVerification, agent: AgentID) throws { verifications.append((agent, verification)) }
    func completedActions(agent: AgentID, since: Date) -> Int { completedToday }
    func pauses() -> [AgentPause] { activePauses }
    func pause(_ pause: AgentPause) throws { activePauses = activePauses.filter { $0.agent != pause.agent } + [pause] }
    func resume(_ agent: AgentID) throws { activePauses.removeAll { $0.agent == agent } }
}

final class RecordingAlerts: ExecutionAlerts, @unchecked Sendable {
    var reviews: [(AgentID, ExecutionVerification)] = []
    func executionNeedsReview(agent: AgentID, verification: ExecutionVerification) { reviews.append((agent, verification)) }
}

final class ExecutionGuardTests: XCTestCase {
    let jobs = AgentID(rawValue: "empleo")
    let moment = Date(timeIntervalSince1970: 1_800_000_000)
    var store: InMemoryExecutionStateStore!
    var alerts: RecordingAlerts!
    var executionGuard: ExecutionGuard!

    override func setUp() {
        store = InMemoryExecutionStateStore()
        alerts = RecordingAlerts()
        let moment = self.moment
        executionGuard = ExecutionGuard(store: store, alerts: alerts, now: { moment })
    }

    var vacancy: Proposal {
        Proposal(id: "li:1", action: .apply, target: .url("https://linkedin.com/jobs/view/1"), title: "Backend", source: "LinkedIn")
    }

    func log(_ itemId: String) -> ActionLogReading {
        .found(
            ActionLog(
                batch: "b1", actions: [ActionRecord(itemId: itemId, action: .apply, target: vacancy.target, outcome: .done, at: moment)]))
    }

    func testApprovingSavesTheApprovedCopyWithWhoApprovedIt() throws {
        let items = try executionGuard.approve([vacancy], batch: "b1", approvedBy: .autoSend)
        XCTAssertEqual(store.approved["b1"], items)
        XCTAssertEqual(items.first?.approvedBy, .autoSend)
        XCTAssertEqual(items.first?.approvedAt, moment)
    }

    func testAuthorizedExecutionIsSavedWithoutPauseOrAlert() throws {
        _ = try executionGuard.approve([vacancy], batch: "b1", approvedBy: .person)
        store.logs["b1"] = log("li:1")
        let verification = executionGuard.verify(batch: "b1", agent: jobs)
        XCTAssertFalse(verification.requiresPause)
        XCTAssertEqual(store.verifications.count, 1)
        XCTAssertNil(executionGuard.pause(of: jobs))
        XCTAssertTrue(alerts.reviews.isEmpty)
    }

    func testUnauthorizedActionPausesTheAgentAndAlertsThePerson() throws {
        _ = try executionGuard.approve([vacancy], batch: "b1", approvedBy: .person)
        store.logs["b1"] = log("li:999")
        executionGuard.verify(batch: "b1", agent: jobs)
        XCTAssertEqual(executionGuard.pause(of: jobs)?.reason, "notApproved")
        XCTAssertEqual(alerts.reviews.first?.0, jobs)
    }

    func testMissingLogPausesTheAgent() throws {
        _ = try executionGuard.approve([vacancy], batch: "b1", approvedBy: .person)
        executionGuard.verify(batch: "b1", agent: jobs)
        XCTAssertEqual(executionGuard.pause(of: jobs)?.reason, "logMissing")
        XCTAssertEqual(alerts.reviews.count, 1)
    }

    func testOnlyThePersonLiftsThePause() throws {
        executionGuard.verify(batch: "b1", agent: jobs)
        XCTAssertNotNil(executionGuard.pause(of: jobs))
        try executionGuard.resume(jobs)
        XCTAssertNil(executionGuard.pause(of: jobs))
    }

    func testRemainingQuotaSubtractsWhatWasAlreadyDoneToday() {
        store.completedToday = 18
        XCTAssertEqual(executionGuard.remainingQuota(of: jobs, dailyLimit: 20), 2)
        store.completedToday = 25
        XCTAssertEqual(executionGuard.remainingQuota(of: jobs, dailyLimit: 20), 0)
        XCTAssertNil(executionGuard.remainingQuota(of: jobs, dailyLimit: nil))
    }
}
