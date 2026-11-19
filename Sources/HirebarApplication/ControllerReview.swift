import Foundation
import HirebarDomain

private let log = Log(.ai)

struct ReviewOutcomeResult {
    let outcome: ReviewOutcome
    let final: [Proposal]
    let summary: String

    static func skippedFailure(_ proposals: [Proposal]) -> ReviewOutcomeResult {
        ReviewOutcomeResult(outcome: .skippedFailure, final: proposals, summary: String(localized: "No se pudo revisar esta vez."))
    }
}

extension Controller {
    @discardableResult
    func reviewThenOffer(
        _ batch: Batch, proposals: [Proposal], title: String, sourceMode: Mode, onOffered: @escaping (Bool) -> Void = { _ in }
    ) -> Bool {
        guard stores.agents.load(AgentKind.owner(of: sourceMode)).reviewEnabled else {
            onOffered(offer(batch, proposals: proposals, title: title))
            return false
        }
        var settled = false
        let settle: (ReviewOutcomeResult) -> Void = { [weak self] result in
            guard let self, !settled else { return }
            settled = true
            self.settleReview(batch, original: proposals, result: result, title: title, onOffered: onOffered)
        }
        reviewInFlight = true
        let started = aiRunner.start(reviewRequest(for: batch, proposals: proposals, sourceMode: sourceMode)) { [weak self] result in
            guard let self else { return }
            settle(self.reviewOutcome(of: result, against: proposals))
        }
        guard case .success = started else {
            settle(.skippedFailure(proposals))
            return true
        }
        guard !settled else { return true }
        clock.after(policy.corridas.reviewTimeout) {
            settle(
                ReviewOutcomeResult(
                    outcome: .skippedTimeout, final: proposals, summary: String(localized: "La revisión no respondió a tiempo.")))
        }
        return true
    }

    func reviewRequest(for batch: Batch, proposals: [Proposal], sourceMode: Mode) -> AIRunRequest {
        AIRunRequest(
            runId: "\(batch.id)-review",
            engine: ai.settings,
            prompt: prompts.reviewPrompt(for: sourceMode, proposals: proposals, owner: stores.config.load().ownerName),
            playbook: Paths.playbook(for: sourceMode),
            profile: TaskProfiles.profile(for: sourceMode, account: nil),
            browser: false
        )
    }

    func reviewOutcome(of result: AIRunResult, against proposals: [Proposal]) -> ReviewOutcomeResult {
        guard !result.authFailed, result.code == 0, !result.output.isEmpty else {
            return .skippedFailure(proposals)
        }
        switch ProposalParser.parse(result.output, rules: targetRules) {
        case .success(let reviewed):
            let changed = reviewed != proposals
            let summary =
                changed
                ? String(localized: "La revisión ajustó el borrador.") : String(localized: "La revisión no encontró cambios.")
            return ReviewOutcomeResult(outcome: changed ? .corrected : .approvedAsIs, final: reviewed, summary: summary)
        case .failure:
            return .skippedFailure(proposals)
        }
    }

    func settleReview(_ batch: Batch, original: [Proposal], result: ReviewOutcomeResult, title: String, onOffered: (Bool) -> Void) {
        reviewInFlight = false
        let draft = ReviewedDraft(
            batch: batch.id, outcome: result.outcome, original: original, final: result.final, summary: result.summary,
            reviewedAt: Date())
        do { try stores.executionState.saveReviewedDraft(draft, batch: batch.id) } catch {
            log.write("Revisión \(batch.id): no pude guardar el resultado (\(error.localizedDescription))")
        }
        var finalBatch = batch
        finalBatch.items = result.final.map { BatchItem($0) }
        onOffered(offer(finalBatch, proposals: result.final, title: title))
        advanceQueue()
    }
}
