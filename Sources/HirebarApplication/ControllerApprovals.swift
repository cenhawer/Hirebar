import Foundation
import HirebarDomain

private let log = Log(.ai)

extension Controller {
    nonisolated static let practiceSummaryLimit = 15

    func simulateIfPracticing(_ batch: Batch) -> Bool {
        let kind = AgentKind.owner(of: batch.mode)
        let agent = stores.agents.load(kind)
        guard agent.practice else { return false }
        let items = executionGuard.approvedItems(batch: batch.id).map(\.proposal)
        do {
            try stores.practice.record(batch: batch.id, agent: kind.rawValue, at: Date(), wouldSend: items)
        } catch {
            log.write("Práctica: no pude guardar lo que habría enviado \(batch.id): \(error.localizedDescription)")
        }
        releaseApproval(of: batch.id)
        var finished = batch
        finished.status = .done
        finished.result = Self.practiceResult
        stores.batches.upsert(finished)
        stores.metrics.bump(batch.mode, Self.practiceMetric, items.count)
        Log(agent: kind).write("Práctica: \(kind.rawValue) simuló \(items.count) acción(es) del lote \(batch.id)")
        reply(Self.practiceSummary(agentName: agent.name, items: items))
        return true
    }

    nonisolated static let practiceResult = "práctica"
    nonisolated static let practiceMetric = "practica"

    static func practiceSummary(agentName: String, items: [Proposal]) -> String {
        let lines = items.prefix(practiceSummaryLimit).map { "• \($0.action.rawValue) · \($0.title) · \($0.target.displayText)" }
        let more = items.count > practiceSummaryLimit ? ["… y \(items.count - practiceSummaryLimit) más."] : []
        return (["Modo práctica: \(agentName) no envió nada. Habría hecho \(items.count):"] + lines + more)
            .joined(separator: "\n")
    }

    func activePause(of agent: AgentID) -> AgentPause? {
        executionGuard.pause(of: agent) ?? unsavedPauses[agent]
    }

    func releaseApproval(of batchId: String) {
        do {
            try executionGuard.release(batch: batchId)
        } catch {
            log.write("Verificación: no pude liberar lo aprobado de \(batchId); su cupo queda reservado hoy")
        }
    }

    func settleInterruptedExecution(_ batchId: String, mode: Mode, items: [BatchItem]) -> [BatchItem] {
        guard executionGuard.hasActionLog(batch: batchId) else {
            releaseApproval(of: batchId)
            return items
        }
        guard let verification = verify(batchId, mode: mode) else { return items }
        let done = Set(verification.verdicts.filter { $0.record?.outcome == .done }.map(\.itemId))
        return items.filter { !done.contains($0.id) }
    }

    func handleAuthFailure(_ batchId: String, mode: Mode, items: [BatchItem]) {
        if var batch = stores.batches.find(id: batchId) {
            let retry = mode.hasItems && !items.isEmpty
            batch.status = retry ? .pending : mode.hasItems ? .done : .interrupted
            if mode.hasItems { batch.items = items }
            stores.batches.upsert(batch)
        }
        log.write("IA: la sesión venció; lote \(batchId) queda para reintentar")
        let now = Date()
        if lastAuthAlert.map({ now.timeIntervalSince($0) > Self.authAlertEvery }) ?? true {
            lastAuthAlert = now
            let expired = "La sesión de \(ai.settings.kind.title) se venció y no pude trabajar. \(aiRunner.loginHint(ai.settings.kind))"
            reply(expired + " Las listas de propuestas y postulaciones quedaron guardadas: responde \"si\" para reintentar la última.")
        }
    }
}
