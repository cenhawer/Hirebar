import Foundation
import HirebarDomain

private let log = Log(.ai)

extension Controller {
    func pausedNotice(_ mode: Mode, _ pause: AgentPause) -> String {
        let kind = AgentKind.owner(of: mode)
        let name = stores.agents.load(kind).name
        return "\(name) está en pausa desde la lista \(pause.batch) porque algo no coincidió con lo aprobado. "
            + "No ejecuto nada de \(name) hasta que escribas \"reanudar \(kind.rawValue)\"."
    }

    func approvedWithinQuota(_ chosen: [BatchItem], from batch: Batch, approvedBy: Approver) -> [BatchItem]? {
        let agentID = ExecutionApprovals.agent(of: batch.mode)
        if let pause = activePause(of: agentID) {
            reply(pausedNotice(batch.mode, pause))
            return nil
        }
        let agentSettings = stores.agents.load(AgentKind.owner(of: batch.mode))
        let plan: ExecutionPlan
        do {
            plan = try executionGuard.approve(
                ExecutionApprovals.proposals(for: batch, items: chosen, store: stores.executionState),
                batch: batch.id,
                approvedBy: approvedBy,
                agent: agentID,
                dailyLimit: agentSettings.dailyLimit
            )
        } catch {
            reply("No pude guardar la copia de lo aprobado, así que no ejecuto la lista: \(error.localizedDescription)")
            return nil
        }
        if !plan.held.isEmpty { holdForPerson(plan.held, from: batch) }
        guard !plan.now.isEmpty else {
            if !plan.held.isEmpty { remove(plan.held.map(\.proposal.id), from: batch.id) }
            if plan.held.isEmpty {
                reply("Hoy ya se cumplió el cupo diario de \(agentSettings.name). La lista sigue pendiente: apruébala mañana.")
            }
            return nil
        }
        let approvedIds = Set(plan.now.map(\.proposal.id))
        let ready = chosen.filter { approvedIds.contains($0.id) }
        let heldIds = Set(plan.held.map(\.proposal.id))
        let deferred = chosen.filter { !approvedIds.contains($0.id) && !heldIds.contains($0.id) }
        if !deferred.isEmpty { deferBeyondQuota(deferred, from: batch, running: ready.count) }
        return ready
    }

    func holdForPerson(_ held: [ApprovedItem], from batch: Batch) {
        let ids = Set(held.map(\.proposal.id))
        let rest = Batch(mode: batch.mode, items: batch.items.filter { ids.contains($0.id) }, status: .pending)
        do {
            try stores.executionState.saveProposals(held.map(\.proposal), batch: rest.id)
        } catch {
            reply("No pude separar los mensajes que necesitan tu revisión; quedan en la lista \(batch.id): \(error.localizedDescription)")
            return
        }
        stores.batches.upsert(rest)
        notifier.announce(
            rest, title: "Estos mensajes no se envían solos",
            footer: "Revisa el texto y responde \"si\" para enviarlos, \"si 1 3\" para elegir o \"no\" para descartar.")
    }

    func remove(_ ids: [String], from batchId: String) {
        guard var batch = stores.batches.find(id: batchId) else { return }
        let removed = Set(ids)
        batch.items.removeAll { removed.contains($0.id) }
        if batch.items.isEmpty {
            batch.status = .done
            if let id = batch.messageId { chat.removeButtons(chatId: stores.config.load().chatId, messageId: id) }
        }
        stores.batches.upsert(batch)
    }

    func deferBeyondQuota(_ items: [BatchItem], from batch: Batch, running count: Int) {
        let rest = Batch(mode: batch.mode, items: items, status: .pending)
        let ids = Set(items.map(\.id))
        let proposals = stores.executionState.proposals(batch: batch.id).filter { ids.contains($0.id) }
        do {
            if !proposals.isEmpty { try stores.executionState.saveProposals(proposals, batch: rest.id) }
        } catch {
            reply("Hoy queda cupo para \(count). No pude guardar los otros \(items.count) para mañana: vuelve a pedirlos cuando aparezcan.")
            return
        }
        stores.batches.upsert(rest)
        reply("Hoy queda cupo para \(count): ejecuto esos y dejo \(items.count) en una lista pendiente para mañana.")
    }

    func prepareScheduledExecution(_ batch: Batch, manual: Bool) -> Bool {
        let agentID = ExecutionApprovals.agent(of: batch.mode)
        if let pause = activePause(of: agentID) {
            reply(pausedNotice(batch.mode, pause))
            return false
        }
        guard batch.mode == .linkedInPublish,
            let proposal = stores.contentAccounts.find(batch.account).flatMap(ExecutionApprovals.publishProposal)
        else {
            log.write("\(batch.mode.rawValue): no se ejecuta sin una lista aprobada")
            if manual { reply("Eso solo se ejecuta sobre una lista que hayas aprobado; no ejecuto nada.") }
            return false
        }
        let agentSettings = stores.agents.load(AgentKind.owner(of: batch.mode))
        do {
            let plan = try executionGuard.approve(
                [proposal], batch: batch.id, approvedBy: manual ? .person : .autoSend, agent: agentID, dailyLimit: agentSettings.dailyLimit)
            guard !plan.now.isEmpty else {
                reply(
                    plan.held.isEmpty
                        ? "Hoy ya se cumplió el cupo diario de \(agentSettings.name); no publico nada más hoy."
                        : "Las publicaciones solo salen cuando respondes \"publica\".")
                return false
            }
            return true
        } catch {
            reply("No pude guardar la copia de lo aprobado, así que no ejecuto nada: \(error.localizedDescription)")
            return false
        }
    }
}
