import Foundation
import HirebarApplication
import HirebarCore
import HirebarDomain

public final class Controller {
    public static let shared = Controller()
    let targetRules = TargetRulesFile.bundled()
    lazy var executionGuard = ExecutionGuard(store: ExecutionApprovals.store, alerts: TelegramExecutionAlerts(), rules: targetRules)
    var unsavedPauses: [AgentID: AgentPause] = [:]
    private var protectedSnapshot: ProtectedFiles.Snapshot?
    static let noNewsMarker = "SIN_NOVEDADES"
    static let maxRunSeconds: TimeInterval = 3600
    static let authAlertEvery: TimeInterval = 3600

    public var onStatusChange: ((String) -> Void)?
    public private(set) var status = "en espera"
    var queue: [(Batch, [BatchItem])] = []
    private var running: Process?
    private var runningBatch: String?
    private var runningMode: Mode?
    private var runningAccount: String?
    private var runStarted: Date?
    private var watchdog: Timer?
    private var lastAuthAlert: Date?

    public var isIdle: Bool { running == nil && queue.isEmpty }
    public var runningAgent: AgentKind? { runningMode.map(AgentKind.owner) }

    public func start() {
        if watchdog == nil {
            let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.stopIfStuck() }
            RunLoop.main.add(timer, forMode: .common)
            watchdog = timer
        }
        Paths.ensure()
        Telegram.shared.onMessage = { [weak self] message in self?.handle(message) }
        Telegram.shared.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.recoverInterrupted() }
    }

    func setStatus(_ text: String) {
        status = text
        onStatusChange?(text)
    }

    var replies: (String) -> Void = Notifier.tell

    func reply(_ text: String) { replies(text) }

    public func autoApprove(_ batch: Batch) {
        approve(batch, picks: [], approvedBy: .autoSend)
    }

    func approve(_ found: Batch?, picks: [Int], approvedBy: Approver = .person) {
        guard var batch = found else {
            reply("No tengo listas pendientes de las últimas 24 horas.")
            return
        }
        guard batch.status == .pending else {
            reply("Esa lista ya está \(batch.status.rawValue).")
            return
        }
        let chosen = picks.isEmpty ? batch.items
            : picks.filter { $0 >= 1 && $0 <= batch.items.count }.map { batch.items[$0 - 1] }
        guard !chosen.isEmpty else {
            reply("Esos números no están en la lista (van del 1 al \(batch.items.count)).")
            return
        }
        guard let ready = approvedWithinQuota(chosen, from: batch, approvedBy: approvedBy) else { return }
        batch.status = .running
        batch.items = ready
        BatchStore.upsert(batch)
        Metrics.bump(batch.mode, "aprobados", ready.count)
        if let id = batch.messageId { Telegram.shared.removeButtons(chatId: Config.load().chatId, messageId: id) }
        queue.append((batch, ready))
        if running == nil {
            runNext()
        } else {
            reply("Anotado: \(AI.capitalizedName) está terminando otra lista y sigue con esta.")
        }
    }

    public func runScheduled(_ mode: Mode, manual: Bool = false, account: String? = nil) {
        if mode == .linkedInDraft && account == nil {
            // Una publicación por cuenta prendida; las programadas, solo en los días de cada cuenta.
            let today = Date()
            let accounts = ContentAccountStore.enabled().filter { manual || $0.runs(on: today) }
            if accounts.isEmpty && manual {
                reply("No tienes cuentas de contenido prendidas. Agrégalas en Ajustes → Cuentas de contenido.")
            }
            for item in accounts { runScheduled(mode, manual: manual, account: item.id) }
            return
        }
        if Scheduler.isIdlePortalScan(mode) {
            if manual { reply("No tienes portales propios activos. Agrégalos en Ajustes → \(AgentStore.load(AgentKind.owner(of: mode)).name).") }
            return
        }
        if (runningMode == mode && runningAccount == account)
            || queue.contains(where: { $0.0.mode == mode && $0.0.account == account }) {
            if manual { reply("Eso ya está en curso.") }
            return
        }
        let batch = Batch(mode: mode, status: .running, manual: manual, account: account)
        if TaskProfiles.profile(for: mode, account: ContentAccountStore.find(account)).canAct {
            guard prepareScheduledExecution(batch, manual: manual) else { return }
        }
        BatchStore.upsert(batch)
        // Una publicación pedida a mano no espera detrás de las búsquedas: va de primera en la fila.
        if manual && mode == .linkedInDraft {
            let ahead = queue.prefix { $0.0.mode == .linkedInDraft && $0.0.isManual }.count
            queue.insert((batch, []), at: ahead)
        } else {
            queue.append((batch, []))
        }
        let accountTitle = ContentAccountStore.find(account)?.title ?? "tu cuenta"
        if manual {
            switch mode {
            case .weeklyReport: reply("Preparando el informe semanal; te lo mando al terminar.")
            case .linkedInDraft:
                reply("Armando la publicación para \(accountTitle) con sus imágenes; te la mando antes de publicar nada."
                      + (running == nil ? "" : " Empieza apenas termine lo que está corriendo ahora."))
            case .linkedInPublish: reply("Publicando en \(accountTitle) la publicación que aprobaste; te confirmo al terminar.")
            case .followUp: reply("Revisando seguimientos ahora; te aviso si escribo a algún cliente.")
            case .prospectingSend: reply("Enviando los correos aprobados; te confirmo al terminar.")
            case .social: reply("Buscando vacantes publicadas en redes; te aviso si encuentro algo.")
            case .prospecting: reply("Buscando empresas y negocios para escribirles; te mando la lista al terminar.")
            case .profileUpdate: reply("Actualizando tu perfil y tus hojas de vida; te mando los PDF al terminar.")
            default: break
            }
        }
        if running == nil { runNext() }
    }

    private func stopIfStuck() {
        guard let process = running, process.isRunning, let started = runStarted,
              Date().timeIntervalSince(started) > Self.maxRunSeconds else { return }
        Log.write("IA: lote \(runningBatch ?? "?") lleva más de 1 hora, se detiene")
        process.terminate()
    }

    private func recoverInterrupted() {
        let since = Date().addingTimeInterval(-24 * 3600)
        for var batch in BatchStore.load() where batch.status == .running {
            if !batch.items.isEmpty && batch.created > since && batch.mode.hasItems {
                batch.status = .pending
                BatchStore.upsert(batch)
                Notifier.announce(batch, title: "Quedaron sin terminar estas \(Self.noun(for: batch.mode)) (la Mac se durmió o se cerró la app)",
                                  footer: "Responde \"si\" para reintentar, \"si 1 3\" para elegir o \"no\" para descartar.")
            } else {
                batch.status = .interrupted
                BatchStore.upsert(batch)
            }
        }
    }

    static func noun(for mode: Mode) -> String {
        mode == .jobs ? "postulaciones" : mode == .followUpSend ? "seguimientos" : "propuestas"
    }

    private func runNext() {
        guard running == nil, !queue.isEmpty else { return }
        let (pending, items) = queue.removeFirst()
        var batch = pending
        Paths.ensure()
        let outURL = Paths.runs.appendingPathComponent("\(batch.id).txt")
        let errURL = Paths.runs.appendingPathComponent("\(batch.id).log")
        FileManager.default.createFile(atPath: outURL.path, contents: nil)
        FileManager.default.createFile(atPath: errURL.path, contents: nil)
        let owner = Config.load().ownerName
        if batch.mode == .linkedInDraft, let account = ContentAccountStore.find(batch.account) {
            SlideRenderer.prepare(account)
        }
        let account = ContentAccountStore.find(batch.account)
        let profile = TaskProfiles.profile(for: batch.mode, account: account)
        if profile.canAct, let pause = activePause(of: ExecutionApprovals.agent(of: batch.mode)) {
            batch.status = batch.mode.hasItems ? .pending : .interrupted
            BatchStore.upsert(batch)
            releaseApproval(of: batch.id)
            reply(Self.pausedNotice(batch.mode, pause))
            runNext()
            return
        }
        if profile.canAct {
            do {
                try executionGuard.prepareRun(batch: batch.id)
            } catch {
                batch.status = .failed
                BatchStore.upsert(batch)
                releaseApproval(of: batch.id)
                reply("No pude limpiar el registro anterior de la lista \(batch.id), así que no la ejecuto: \(error.localizedDescription)")
                runNext()
                return
            }
        }
        let request = ClaudeCLI.LaunchRequest(
            prompt: AgentPrompts.prompt(for: batch, items: items, owner: owner),
            playbook: Paths.playbook(for: batch.mode),
            profile: profile,
            browser: TaskProfiles.needsBrowser(batch.mode, account: account)
        )
        let launch = ClaudeCLI.makeProcess(engine: AI.settings, request: request, output: outURL, errors: errURL)
        guard case .success(let process) = launch else {
            if case .failure(let problem) = launch {
                reply(problem.message)
                setStatus(problem.status)
            }
            batch.status = .failed
            BatchStore.upsert(batch)
            if profile.canAct { releaseApproval(of: batch.id) }
            runNext()
            return
        }
        let batchId = batch.id
        let mode = batch.mode
        process.terminationHandler = { finished in
            let code = finished.terminationStatus
            DispatchQueue.main.async {
                Controller.shared.finished(batchId, mode: mode, items: items, code: code, outURL: outURL, errURL: errURL)
            }
        }
        protectedSnapshot = profile.canAct ? Self.protectedFiles()?.snapshot() : nil
        do {
            try process.run()
        } catch {
            batch.status = .failed
            BatchStore.upsert(batch)
            if profile.canAct { releaseApproval(of: batch.id) }
            reply("No pude abrir \(AI.name): \(error.localizedDescription)")
            runNext()
            return
        }
        running = process
        runningBatch = batchId
        runningMode = mode
        runningAccount = batch.account
        runStarted = Date()
        setStatus(AgentPrompts.statusText(for: mode, count: items.count, since: TextTools.shortTime()))
        if mode == .freelance || mode == .jobs {
            reply("\(AI.capitalizedName) empezó: \(items.count) \(Self.noun(for: mode)). Te aviso cuando termine (suele tardar 5–20 min).")
        }
        Log.write("IA: inicia lote \(batchId) con \(items.count) elemento(s), perfil \(profile.phase)")
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.maxRunSeconds) { [weak self] in
            guard let self, self.runningBatch == batchId, let process = self.running, process.isRunning else { return }
            Log.write("IA: lote \(batchId) superó 1 hora, se detiene")
            process.terminate()
        }
    }

    private func finished(_ batchId: String, mode: Mode, items: [BatchItem], code: Int32, outURL: URL, errURL: URL) {
        running = nil
        runningBatch = nil
        runningMode = nil
        runningAccount = nil
        let output = ((try? String(contentsOf: outURL, encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let errors = (try? String(contentsOf: errURL, encoding: .utf8)) ?? ""
        Log.write("IA: lote \(batchId) terminó con código \(code)")

        let acts = TaskProfiles.profile(for: mode, account: nil).canAct
        if acts { restoreProtectedFiles(after: batchId) }
        if code != 0 && ClaudeCLI.isAuthFailure(output + "\n" + errors) {
            handleAuthFailure(batchId, mode: mode, items: acts ? settleInterruptedExecution(batchId, mode: mode, items: items) : items)
        } else {
            if var batch = BatchStore.find(id: batchId) {
                batch.status = code == 0 ? .done : .failed
                batch.result = String(output.suffix(2000))
                BatchStore.upsert(batch)
            }
            report(batchId, mode: mode, code: code, output: output)
            if acts { verify(batchId, mode: mode) }
        }
        setStatus(queue.isEmpty ? "en espera" : "siguiente lista…")
        runNext()
    }

    @discardableResult
    func verify(_ batchId: String, mode: Mode) -> ExecutionVerification? {
        let agent = ExecutionApprovals.agent(of: mode)
        do {
            return try executionGuard.verify(batch: batchId, agent: agent)
        } catch ExecutionGuardFailure.pauseNotSaved(let pause, let verification) {
            unsavedPauses[agent] = pause
            Log.write("Verificación: no pude guardar la pausa de \(agent.rawValue); queda en pausa mientras la app siga abierta")
            return verification
        } catch ExecutionGuardFailure.verificationNotSaved(let verification) {
            Log.write("Verificación: no pude guardar la verificación de \(batchId); su cupo queda reservado")
            return verification
        } catch {
            Log.write("Verificación: \(batchId) falló: \(error.localizedDescription)")
            return nil
        }
    }

    static func protectedFiles() -> ProtectedFiles? {
        (try? EngineProfiles.bundled()).map { ProtectedFiles(folder: Paths.workspace, patterns: $0.restoredFiles) }
    }

    private func restoreProtectedFiles(after batchId: String) {
        guard let before = protectedSnapshot, let files = Self.protectedFiles() else { return }
        protectedSnapshot = nil
        let restored = files.restoreChanges(since: before)
        guard !restored.isEmpty else { return }
        Log.write("Ejecución \(batchId): restauré archivos protegidos que cambió la IA (\(restored.joined(separator: ", ")))")
        reply("\(AI.capitalizedName) cambió archivos que no debía tocar (\(restored.joined(separator: ", "))); los dejé como estaban.")
    }

    func activePause(of agent: AgentID) -> AgentPause? {
        executionGuard.pause(of: agent) ?? unsavedPauses[agent]
    }

    func releaseApproval(of batchId: String) {
        do {
            try executionGuard.release(batch: batchId)
        } catch {
            Log.write("Verificación: no pude liberar lo aprobado de \(batchId); su cupo queda reservado hoy")
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

    private func handleAuthFailure(_ batchId: String, mode: Mode, items: [BatchItem]) {
        if var batch = BatchStore.find(id: batchId) {
            let retry = mode.hasItems && !items.isEmpty
            batch.status = retry ? .pending : mode.hasItems ? .done : .interrupted
            if mode.hasItems { batch.items = items }
            BatchStore.upsert(batch)
        }
        Log.write("IA: la sesión venció; lote \(batchId) queda para reintentar")
        let now = Date()
        if lastAuthAlert.map({ now.timeIntervalSince($0) > Self.authAlertEvery }) ?? true {
            lastAuthAlert = now
            reply("La sesión de \(AI.settings.kind.title) se venció y no pude trabajar. \(ClaudeCLI.loginHint(AI.settings.kind)) Las listas de propuestas y postulaciones quedaron guardadas: responde \"si\" para reintentar la última.")
        }
    }

    private func report(_ batchId: String, mode: Mode, code: Int32, output: String) {
        if code == 0 && TaskProfiles.executionMode(for: mode) != nil {
            offerProposals(from: output, mode: mode)
            if output.contains(Self.noNewsMarker) { return }
        }
        if code == 0 && (mode == .followUp || mode == .social || mode == .portalScanJobs || mode == .portalScanFreelance)
            && output.contains(Self.noNewsMarker) {
            Log.write("\(mode.rawValue): sin novedades")
            if batchId.hasPrefix("gm-") {
                let summary = output.replacingOccurrences(of: Self.noNewsMarker, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                reply("Seguimientos: hoy no tocaba escribirle a nadie.\n\n" + (summary.isEmpty ? "Sin más detalle." : String(summary.suffix(3500))))
            }
            return
        }
        guard code == 0 && !output.isEmpty else {
            let detail = output.isEmpty ? "sin salida" : String(output.suffix(1500))
            reply("\(AI.capitalizedName) terminó con error (código \(code)). Detalle: \(detail)\nRegistro: workspace/ejecuciones/\(batchId).log")
            return
        }
        reply(String(ProposalParser.removingBlock(from: output).suffix(3800)))
        switch mode {
        case .prospecting: offerProspectingEmails()
        case .profileUpdate: finishProfileUpdate()
        case .linkedInDraft:
            sendSlides(BatchStore.find(id: batchId)?.account)
        default: break
        }
    }

    private func sendSlides(_ accountId: String?) {
        guard let account = ContentAccountStore.find(accountId) else {
            reply("No encontré la cuenta de esta publicación en Ajustes → Cuentas de contenido.")
            return
        }
        let several = ContentAccountStore.load().count > 1
        let publish = several ? "publica \(account.id)" : "publica"
        let change = several ? "post \(account.id) cambia <qué>" : "post cambia <qué>"
        let skip = several ? "post \(account.id) salta" : "post salta"
        let ask = "¿Lo subo a \(account.title)? Responde \"\(publish)\" para subirlo tal cual, \"\(change)\" para ajustarlo o \"\(skip)\" para no publicarlo."
        SlideRenderer.renderAll(account) { [weak self] made, failed in
            var notes: [String] = []
            if made.isEmpty {
                notes.append("Esta vez no salieron imágenes (\(AI.name) no dejó las láminas o Chrome no pudo convertirlas).")
            } else if failed > 0 {
                notes.append("\(failed) lámina(s) no se pudieron convertir.")
            }
            Notifier.sendPhotos(made, caption: "\(account.title): imágenes de la publicación (\(made.count))") {
                if let text = Self.copyText(account.draft) {
                    self?.reply("Texto de la publicación de \(account.title), listo para copiar:\n\n\(text)")
                }
                guard account.video else {
                    self?.reply((notes + [ask]).joined(separator: " "))
                    return
                }
                ReelRenderer.renderPreview(account) { video, problem in
                    let rest = {
                        if let script = ReelRenderer.readingScript(account) {
                            UserDefaults.standard.set(account.id, forKey: Self.waitingVoiceKey)
                            self?.reply(script)
                        }
                        if let text = Self.copyText(account.videoFolder.appendingPathComponent("texto.md")) {
                            self?.reply("Descripción del video de \(account.title), lista para copiar:\n\n\(text)")
                        }
                        self?.reply((notes + [ask + " El video se sube cuando me mandes tu voz."]).joined(separator: " "))
                    }
                    guard let video else {
                        notes.append("No salió la vista previa del video: \(problem ?? "sin detalle").")
                        rest()
                        return
                    }
                    Notifier.sendVideo(video, caption: "\(account.title): vista previa del video, sin voz") { rest() }
                }
            }
        }
    }

    /// Cuenta cuyo video está esperando la nota de voz de la persona.
    static let waitingVoiceKey = "video.esperandoVoz"

    /// Texto de un archivo para mandarlo a Telegram tal cual, listo para copiar y pegar.
    static func copyText(_ file: URL) -> String? {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.count > 10 ? String(clean.prefix(3800)) : nil
    }

    static let proposalSeenWindow: TimeInterval = 30 * 86400

    private func offerProposals(from output: String, mode: Mode) {
        guard let execution = TaskProfiles.executionMode(for: mode) else { return }
        let proposals: [Proposal]
        switch ProposalParser.parse(output, rules: targetRules) {
        case .success(let parsed):
            proposals = parsed
        case .failure(.blockMissing):
            return
        case .failure(let failure):
            Log.write("\(mode.rawValue): la lista de propuestas no es válida (\(failure))")
            reply("\(AI.capitalizedName) no dejó la lista en el formato esperado; no la muestro. El detalle quedó en el registro.")
            return
        }
        let intake = ProposalIntake(window: Self.proposalSeenWindow, rules: targetRules).accept(
            proposals,
            allowed: TaskProfiles.allowedProposals(for: mode),
            seen: ExecutionApprovals.store.seenProposals(),
            now: Date()
        )
        for proposal in intake.rejected {
            Log.write("\(mode.rawValue): descartada una propuesta con acción no permitida para esta tarea (\(proposal.action.rawValue))")
        }
        let fresh = intake.fresh
        guard !fresh.isEmpty else { return }
        let batch = Batch(mode: execution, items: fresh.map { BatchItem($0) }, status: .pending)
        guard offer(batch, proposals: fresh, title: Self.proposalsTitle(for: mode, count: fresh.count)) else { return }
        do {
            try ExecutionApprovals.store.saveSeenProposals(intake.seen)
        } catch {
            Log.write("\(mode.rawValue): no pude guardar qué propuestas ya mostré: \(error.localizedDescription)")
        }
    }

    @discardableResult
    private func offer(_ batch: Batch, proposals: [Proposal], title: String) -> Bool {
        do {
            try ExecutionApprovals.store.saveProposals(proposals, batch: batch.id)
        } catch {
            Log.write("\(batch.mode.rawValue): no pude guardar la copia de las propuestas: \(error.localizedDescription)")
            reply("No pude guardar la lista para aprobar, así que no te la muestro: \(error.localizedDescription)")
            return false
        }
        BatchStore.upsert(batch)
        Metrics.bump(batch.mode, "avisados", proposals.count)
        let auto = AgentStore.load(AgentKind.owner(of: batch.mode)).autoApprove
        let footer =
            auto
            ? "\(AI.capitalizedName) ya los está procesando; te aviso al terminar."
            : "Responde \"si\" para que \(AI.name) los procese, \"si 1 3\" para elegir o \"no\" para descartar."
        Notifier.announce(batch, title: title + (auto ? " (envío automático)" : ""), footer: footer)
        if auto { autoApprove(batch) }
        return true
    }

    private func finishProfileUpdate() {
        ProfileRequests.clear()
        let profile = Profile.load()
        guard !profile.cvVariants.isEmpty else {
            reply("perfil.json no tiene hojas de vida definidas (cvVariants), así que no generé PDF.")
            return
        }
        CVRenderer.renderAll(profile) { [weak self] result in
            for file in result.made {
                Notifier.sendFile(file, caption: "Hoja de vida actualizada: \(file.lastPathComponent)")
            }
            var lines = ["Hojas de vida: \(result.made.count) de \(profile.cvVariants.count) listas."]
            if !result.missing.isEmpty { lines.append("\(AI.capitalizedName) no dejó el HTML de: \(result.missing.joined(separator: ", ")).") }
            if !result.failed.isEmpty { lines.append("No pude crear el PDF de: \(result.failed.joined(separator: ", ")) (revisa que Google Chrome esté instalado).") }
            self?.reply(lines.joined(separator: "\n"))
        }
    }

    private func offerProspectingEmails() {
        switch ExecutionApprovals.emailDrafts(rules: targetRules) {
        case .none:
            return
        case .invalid(let ids):
            let numbers = ids.joined(separator: ", ")
            Log.write("Prospección: correos incompletos o repetidos en pendientes.json (\(numbers))")
            reply("\(AI.capitalizedName) dejó correos sin destinatario, asunto o texto válidos (\(numbers)); no te muestro la lista.")
        case .found(let drafts):
            let batch = Batch(mode: .prospectingSend, items: drafts.map { BatchItem($0.proposal, kind: $0.kind) }, status: .pending)
            offer(batch, proposals: drafts.map(\.proposal), title: "Correos de hoy: \(drafts.count) para aprobar")
        }
    }

    static func proposalsTitle(for mode: Mode, count: Int) -> String {
        switch mode {
        case .social: return "Redes: \(count) publicación(es) con vacantes para ti"
        case .followUp: return "Seguimientos: \(count) para aprobar"
        case .portalScanFreelance: return "Tus portales: \(count) proyecto(s) para ti"
        default: return "Tus portales: \(count) vacante(s) para ti"
        }
    }

    static func pausedNotice(_ mode: Mode, _ pause: AgentPause) -> String {
        let kind = AgentKind.owner(of: mode)
        let name = AgentStore.load(kind).name
        return "\(name) está en pausa desde la lista \(pause.batch) porque algo no coincidió con lo aprobado. "
            + "No ejecuto nada de \(name) hasta que escribas \"reanudar \(kind.rawValue)\"."
    }

    private func approvedWithinQuota(_ chosen: [BatchItem], from batch: Batch, approvedBy: Approver) -> [BatchItem]? {
        let agentID = ExecutionApprovals.agent(of: batch.mode)
        if let pause = activePause(of: agentID) {
            reply(Self.pausedNotice(batch.mode, pause))
            return nil
        }
        let agentSettings = AgentStore.load(AgentKind.owner(of: batch.mode))
        let plan: ExecutionPlan
        do {
            plan = try executionGuard.approve(
                ExecutionApprovals.proposals(for: batch, items: chosen),
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

    private func holdForPerson(_ held: [ApprovedItem], from batch: Batch) {
        let ids = Set(held.map(\.proposal.id))
        let rest = Batch(mode: batch.mode, items: batch.items.filter { ids.contains($0.id) }, status: .pending)
        do {
            try ExecutionApprovals.store.saveProposals(held.map(\.proposal), batch: rest.id)
        } catch {
            reply("No pude separar los mensajes que necesitan tu revisión; quedan en la lista \(batch.id): \(error.localizedDescription)")
            return
        }
        BatchStore.upsert(rest)
        Notifier.announce(
            rest, title: "Estos mensajes no se envían solos",
            footer: "Revisa el texto y responde \"si\" para enviarlos, \"si 1 3\" para elegir o \"no\" para descartar.")
    }

    private func remove(_ ids: [String], from batchId: String) {
        guard var batch = BatchStore.find(id: batchId) else { return }
        let removed = Set(ids)
        batch.items.removeAll { removed.contains($0.id) }
        if batch.items.isEmpty {
            batch.status = .done
            if let id = batch.messageId { Telegram.shared.removeButtons(chatId: Config.load().chatId, messageId: id) }
        }
        BatchStore.upsert(batch)
    }

    private func deferBeyondQuota(_ items: [BatchItem], from batch: Batch, running count: Int) {
        let rest = Batch(mode: batch.mode, items: items, status: .pending)
        let ids = Set(items.map(\.id))
        let proposals = ExecutionApprovals.store.proposals(batch: batch.id).filter { ids.contains($0.id) }
        do {
            if !proposals.isEmpty { try ExecutionApprovals.store.saveProposals(proposals, batch: rest.id) }
        } catch {
            reply("Hoy queda cupo para \(count). No pude guardar los otros \(items.count) para mañana: vuelve a pedirlos cuando aparezcan.")
            return
        }
        BatchStore.upsert(rest)
        reply("Hoy queda cupo para \(count): ejecuto esos y dejo \(items.count) en una lista pendiente para mañana.")
    }

    private func prepareScheduledExecution(_ batch: Batch, manual: Bool) -> Bool {
        let agentID = ExecutionApprovals.agent(of: batch.mode)
        if let pause = activePause(of: agentID) {
            reply(Self.pausedNotice(batch.mode, pause))
            return false
        }
        guard batch.mode == .linkedInPublish,
            let proposal = ContentAccountStore.find(batch.account).flatMap(ExecutionApprovals.publishProposal)
        else {
            Log.write("\(batch.mode.rawValue): no se ejecuta sin una lista aprobada")
            if manual { reply("Eso solo se ejecuta sobre una lista que hayas aprobado; no ejecuto nada.") }
            return false
        }
        let agentSettings = AgentStore.load(AgentKind.owner(of: batch.mode))
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
