import Foundation
import HirebarDomain
import XCTest

@testable import HirebarApplication
@testable import HirebarDomain

struct StoreFailure: Error {}

final class InMemoryExecutionStateStore: ExecutionStateStore, @unchecked Sendable {
    var storedProposals: [String: [Proposal]] = [:]
    var approved: [String: [ApprovedItem]] = [:]
    var logs: [String: ActionLogReading] = [:]
    var verifications: [(AgentID, ExecutionVerification)] = []
    var activePauses: [AgentPause] = []
    var consumedToday = 0
    var contacted: [Target] = []
    var seen: [String: Date] = [:]
    var failsToPause = false
    var failsToSaveVerification = false

    func proposals(batch: String) -> [Proposal] { storedProposals[batch] ?? [] }
    func saveProposals(_ proposals: [Proposal], batch: String) throws { storedProposals[batch] = proposals }
    func approvedItems(batch: String) -> [ApprovedItem] { approved[batch] ?? [] }
    func saveApproved(_ items: [ApprovedItem], batch: String, agent: AgentID) throws { approved[batch] = items }
    func releaseApproval(batch: String) throws { approved[batch] = nil }
    func actionLog(batch: String) -> ActionLogReading { logs[batch] ?? .missing }
    func discardActionLog(batch: String) throws { logs[batch] = nil }
    func save(_ verification: ExecutionVerification, agent: AgentID) throws {
        if failsToSaveVerification { throw StoreFailure() }
        verifications.append((agent, verification))
    }
    func consumedActions(agent: AgentID, since: Date) -> Int { consumedToday + approved.values.reduce(0) { $0 + $1.count } }
    func contactedTargets(agent: AgentID) -> [Target] { contacted }
    func seenProposals() -> [String: Date] { seen }
    func saveSeenProposals(_ seen: [String: Date]) throws { self.seen = seen }
    func pauses() -> [AgentPause] { activePauses }
    func pause(_ pause: AgentPause) throws {
        if failsToPause { throw StoreFailure() }
        activePauses = activePauses.filter { $0.agent != pause.agent } + [pause]
    }
    func resume(_ agent: AgentID) throws { activePauses.removeAll { $0.agent == agent } }
    func removeRecords(before date: Date) throws {}
}

struct Review {
    let agent: AgentID
    let verification: ExecutionVerification
    let pauseSaved: Bool
}

final class RecordingAlerts: ExecutionAlerts, @unchecked Sendable {
    var reviews: [Review] = []
    func executionNeedsReview(agent: AgentID, verification: ExecutionVerification, pauseSaved: Bool) {
        reviews.append(Review(agent: agent, verification: verification, pauseSaved: pauseSaved))
    }
}

@MainActor
final class ExecutionGuardTests: XCTestCase {
    let jobs = AgentID(rawValue: "empleo")
    let moment = Date(timeIntervalSince1970: 1_800_000_000)
    var store: InMemoryExecutionStateStore!
    var alerts: RecordingAlerts!
    var executionGuard: ExecutionGuard!

    override func setUp() async throws {
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
        let plan = try executionGuard.approve([vacancy], batch: "b1", approvedBy: .autoSend, agent: jobs, dailyLimit: nil)
        XCTAssertEqual(store.approved["b1"], plan.now)
        XCTAssertEqual(plan.now.first?.approvedBy, .autoSend)
        XCTAssertEqual(plan.now.first?.approvedAt, moment)
    }

    func testApprovingSavesOnlyWhatFitsInTheRemainingQuota() throws {
        store.consumedToday = 19
        let other = Proposal(id: "li:2", action: .apply, target: .url("https://linkedin.com/jobs/view/2"), title: "API", source: "LinkedIn")
        let plan = try executionGuard.approve([vacancy, other], batch: "b1", approvedBy: .person, agent: jobs, dailyLimit: 20)
        XCTAssertEqual(store.approved["b1"]?.map(\.proposal.id), ["li:1"])
        XCTAssertEqual(plan.deferred.map(\.proposal.id), ["li:2"])
    }

    func testAutomaticApprovalNeverCoversClientRepliesOrPublications() throws {
        let reply = Proposal(
            id: "r1", action: .replyToClient, target: .email("cliente@acme.com"), title: "Acme", source: "Gmail", text: "Gracias.")
        let post = Proposal(
            id: "empresa", action: .publish, target: .account(network: "instagram", handle: "empresa"), title: "Post", source: "IG")
        let plan = try executionGuard.approve([vacancy, reply, post], batch: "b1", approvedBy: .autoSend, agent: jobs, dailyLimit: nil)
        XCTAssertEqual(plan.now.map(\.proposal.id), ["li:1"])
        XCTAssertEqual(Set(plan.held.map(\.proposal.id)), ["r1", "empresa"])
        XCTAssertTrue(plan.deferred.isEmpty)
        let byPerson = try executionGuard.approve([reply, post], batch: "b2", approvedBy: .person, agent: jobs, dailyLimit: nil)
        XCTAssertEqual(byPerson.now.count, 2)
    }

    func testAuthorizedExecutionIsSavedWithoutPauseOrAlert() throws {
        _ = try executionGuard.approve([vacancy], batch: "b1", approvedBy: .person, agent: jobs, dailyLimit: nil)
        store.logs["b1"] = log("li:1")
        let verification = try executionGuard.verify(batch: "b1", agent: jobs)
        XCTAssertFalse(verification.requiresPause)
        XCTAssertEqual(store.verifications.count, 1)
        XCTAssertNil(executionGuard.pause(of: jobs))
        XCTAssertTrue(alerts.reviews.isEmpty)
    }

    func testUnauthorizedActionPausesTheAgentAndAlertsThePerson() throws {
        _ = try executionGuard.approve([vacancy], batch: "b1", approvedBy: .person, agent: jobs, dailyLimit: nil)
        store.logs["b1"] = log("li:999")
        try executionGuard.verify(batch: "b1", agent: jobs)
        XCTAssertEqual(executionGuard.pause(of: jobs)?.reason, "notApproved")
        XCTAssertEqual(alerts.reviews.first?.agent, jobs)
    }

    func testMissingLogPausesTheAgent() throws {
        _ = try executionGuard.approve([vacancy], batch: "b1", approvedBy: .person, agent: jobs, dailyLimit: nil)
        try executionGuard.verify(batch: "b1", agent: jobs)
        XCTAssertEqual(executionGuard.pause(of: jobs)?.reason, "logMissing")
        XCTAssertEqual(alerts.reviews.count, 1)
    }

    func testOnlyThePersonLiftsThePause() throws {
        try executionGuard.verify(batch: "b1", agent: jobs)
        XCTAssertNotNil(executionGuard.pause(of: jobs))
        try executionGuard.resume(jobs)
        XCTAssertNil(executionGuard.pause(of: jobs))
    }

    var followUp: Proposal {
        Proposal(
            id: "s1", action: .sendFollowUp, target: .url("https://workana.com/job/app"), title: "App", source: "Workana", text: "Una idea."
        )
    }

    func testListsApprovedBeforeTheFirstFinishesShareTheDailyQuota() throws {
        let other = Proposal(id: "li:2", action: .apply, target: .url("https://linkedin.com/jobs/view/2"), title: "API", source: "LinkedIn")
        let first = try executionGuard.approve([vacancy], batch: "b1", approvedBy: .person, agent: jobs, dailyLimit: 1)
        let second = try executionGuard.approve([other], batch: "b2", approvedBy: .person, agent: jobs, dailyLimit: 1)
        XCTAssertEqual(first.now.count, 1)
        XCTAssertTrue(second.now.isEmpty)
        XCTAssertEqual(second.deferred.map(\.proposal.id), ["li:2"])
        XCTAssertNil(store.approved["b2"])
    }

    func testReleasingAnApprovalThatNeverRanFreesItsQuota() throws {
        _ = try executionGuard.approve([vacancy], batch: "b1", approvedBy: .person, agent: jobs, dailyLimit: 1)
        try executionGuard.release(batch: "b1")
        XCTAssertEqual(executionGuard.remainingQuota(of: jobs, dailyLimit: 1), 1)
    }

    func testAutomaticFollowUpToSomeoneNeverContactedWaitsForThePerson() throws {
        let plan = try executionGuard.approve([followUp], batch: "b1", approvedBy: .autoSend, agent: jobs, dailyLimit: nil)
        XCTAssertEqual(plan.held.map(\.proposal.id), ["s1"])
        store.contacted = [.url("https://www.workana.com/job/app/")]
        let known = try executionGuard.approve([followUp], batch: "b2", approvedBy: .autoSend, agent: jobs, dailyLimit: nil)
        XCTAssertEqual(known.now.map(\.proposal.id), ["s1"])
    }

    func testAutomaticColdEmailWaitsForThePerson() throws {
        let cold = Proposal(
            id: "n1", action: .sendEmail, target: .email("contacto@acme.com"), title: "Hola", source: "Acme", text: "Texto")
        let plan = try executionGuard.approve([cold], batch: "b1", approvedBy: .autoSend, agent: jobs, dailyLimit: nil)
        XCTAssertEqual(plan.held.map(\.proposal.id), ["n1"])
        let byPerson = try executionGuard.approve([cold], batch: "b2", approvedBy: .person, agent: jobs, dailyLimit: nil)
        XCTAssertEqual(byPerson.now.map(\.proposal.id), ["n1"])
    }

    func testPauseThatCannotBeSavedStillAlertsAndFails() {
        store.failsToPause = true
        XCTAssertThrowsError(try executionGuard.verify(batch: "b1", agent: jobs)) { error in
            guard case ExecutionGuardFailure.pauseNotSaved(let pause, _) = error else { return XCTFail("debía fallar la pausa") }
            XCTAssertEqual(pause.reason, "logMissing")
        }
        XCTAssertEqual(alerts.reviews.first?.pauseSaved, false)
    }

    func testVerificationThatCannotBeSavedIsReported() throws {
        _ = try executionGuard.approve([vacancy], batch: "b1", approvedBy: .person, agent: jobs, dailyLimit: nil)
        store.logs["b1"] = log("li:1")
        store.failsToSaveVerification = true
        XCTAssertThrowsError(try executionGuard.verify(batch: "b1", agent: jobs))
        XCTAssertNil(executionGuard.pause(of: jobs))
    }

    func testPreparingARunDiscardsTheLogOfAPreviousRun() throws {
        store.logs["b1"] = log("li:1")
        XCTAssertTrue(executionGuard.hasActionLog(batch: "b1"))
        try executionGuard.prepareRun(batch: "b1")
        XCTAssertFalse(executionGuard.hasActionLog(batch: "b1"))
    }

    func testRemainingQuotaSubtractsWhatWasAlreadyDoneToday() {
        store.consumedToday = 18
        XCTAssertEqual(executionGuard.remainingQuota(of: jobs, dailyLimit: 20), 2)
        store.consumedToday = 25
        XCTAssertEqual(executionGuard.remainingQuota(of: jobs, dailyLimit: 20), 0)
        XCTAssertNil(executionGuard.remainingQuota(of: jobs, dailyLimit: nil))
    }
}
