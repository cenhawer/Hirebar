import Foundation
import HirebarDomain

private let log = Log(.ai)

extension Controller {
    static func noun(for mode: Mode) -> String {
        mode == .jobs ? "postulaciones" : mode == .followUpSend ? "seguimientos" : "propuestas"
    }

    func runNext() {
        guard running == nil, !queue.isEmpty else { return }
        let (batch, items) = queue.removeFirst()
        if batch.mode == .linkedInDraft, let account = stores.contentAccounts.find(batch.account) {
            media.prepareSlides(for: account)
        }
        let account = stores.contentAccounts.find(batch.account)
        let profile = TaskProfiles.profile(for: batch.mode, account: account)
        guard readyToLaunch(batch, profile: profile) else {
            runNext()
            return
        }
        let request = AIRunRequest(
            runId: batch.id,
            engine: ai.settings,
            prompt: prompts.prompt(for: batch, items: items, owner: stores.config.load().ownerName),
            playbook: Paths.playbook(for: batch.mode),
            profile: profile,
            browser: TaskProfiles.needsBrowser(
                batch.mode, performanceCheckDue: account.map(stores.contentAccounts.needsPerformanceCheck) ?? false)
        )
        launch(request, batch: batch, items: items)
    }

    func readyToLaunch(_ pending: Batch, profile: RunProfile) -> Bool {
        guard profile.canAct else { return true }
        var batch = pending
        if let pause = activePause(of: ExecutionApprovals.agent(of: batch.mode)) {
            batch.status = batch.mode.hasItems ? .pending : .interrupted
            stores.batches.upsert(batch)
            releaseApproval(of: batch.id)
            reply(pausedNotice(batch.mode, pause))
            return false
        }
        if simulateIfPracticing(batch) { return false }
        do {
            try executionGuard.prepareRun(batch: batch.id)
            return true
        } catch {
            batch.status = .failed
            stores.batches.upsert(batch)
            releaseApproval(of: batch.id)
            reply(
                String(
                    localized:
                        """
                        No pude limpiar el registro anterior de la lista \(batch.id), así que no la ejecuto: \
                        \(error.localizedDescription)
                        """
                ))
            return false
        }
    }

    func launch(_ request: AIRunRequest, batch pending: Batch, items: [BatchItem]) {
        var batch = pending
        let batchId = batch.id
        let mode = batch.mode
        let started = aiRunner.start(request) { [weak self] result in
            self?.finished(batchId, mode: mode, items: items, result: result)
        }
        guard case .success(let run) = started else {
            if case .failure(let failure) = started { explain(failure) }
            batch.status = .failed
            stores.batches.upsert(batch)
            if request.profile.canAct { releaseApproval(of: batch.id) }
            runNext()
            return
        }
        running = run
        runningBatch = batchId
        runningMode = mode
        runningAccount = batch.account
        runStarted = Date()
        setStatus(AgentPrompts.statusText(for: mode, count: items.count, since: TextTools.shortTime()))
        if mode == .freelance || mode == .jobs {
            reply(
                String(
                    localized:
                        """
                        \(ai.capitalizedName) empezó: \(items.count) \(Self.noun(for: mode)). Te aviso cuando termine \
                        (suele tardar 5–20 min).
                        """
                ))
        }
        let phase = request.profile.phase
        Log(agent: AgentKind.owner(of: mode)).write("IA: inicia lote \(batchId) con \(items.count) elemento(s), perfil \(phase)")
        clock.after(Self.maxRunSeconds) { [weak self] in
            guard let self, self.runningBatch == batchId, let run = self.running, run.isRunning else { return }
            log.write("IA: lote \(batchId) superó 1 hora, se detiene")
            run.stop()
        }
    }

    func explain(_ failure: AIRunFailure) {
        switch failure {
        case .unavailable(let message, let status):
            reply(message)
            setStatus(status)
        case .couldNotOpen(let detail):
            reply(String(localized: "No pude abrir \(ai.name): \(detail)"))
        }
    }

    func finished(_ batchId: String, mode: Mode, items: [BatchItem], result: AIRunResult) {
        running = nil
        runningBatch = nil
        runningMode = nil
        runningAccount = nil
        let code = result.code
        let output = result.output
        Log(agent: AgentKind.owner(of: mode)).write("IA: lote \(batchId) terminó con código \(code)")

        let acts = TaskProfiles.profile(for: mode, account: nil).canAct
        if acts { reportRestoredFiles(result.restoredFiles, after: batchId) }
        if result.authFailed {
            handleAuthFailure(batchId, mode: mode, items: acts ? settleInterruptedExecution(batchId, mode: mode, items: items) : items)
        } else {
            if var batch = stores.batches.find(id: batchId) {
                batch.status = code == 0 ? .done : .failed
                batch.result = String(output.suffix(2000))
                stores.batches.upsert(batch)
            }
            report(batchId, mode: mode, code: code, output: output)
            if acts { verify(batchId, mode: mode) }
        }
        setStatus(queue.isEmpty ? String(localized: "en espera") : String(localized: "siguiente lista…"))
        runNext()
    }

    @discardableResult
    func verify(_ batchId: String, mode: Mode) -> ExecutionVerification? {
        let agent = ExecutionApprovals.agent(of: mode)
        do {
            return try executionGuard.verify(batch: batchId, agent: agent)
        } catch ExecutionGuardFailure.pauseNotSaved(let pause, let verification) {
            unsavedPauses[agent] = pause
            log.write("Verificación: no pude guardar la pausa de \(agent.rawValue); queda en pausa mientras la app siga abierta")
            return verification
        } catch ExecutionGuardFailure.verificationNotSaved(let verification) {
            log.write("Verificación: no pude guardar la verificación de \(batchId); su cupo queda reservado")
            return verification
        } catch {
            log.write("Verificación: \(batchId) falló: \(error.localizedDescription)")
            return nil
        }
    }

    func reportRestoredFiles(_ restored: [String], after batchId: String) {
        guard !restored.isEmpty else { return }
        log.write("Ejecución \(batchId): restauré archivos protegidos que cambió la IA (\(restored.joined(separator: ", ")))")
        reply(
            String(
                localized:
                    """
                    \(ai.capitalizedName) cambió archivos que no debía tocar (\(restored.joined(separator: ", "))); \
                    los dejé como estaban.
                    """
            ))
    }
}
