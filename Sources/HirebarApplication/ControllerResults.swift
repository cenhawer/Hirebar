import Foundation
import HirebarDomain

private let log = Log(.ai)

extension Controller {
    func report(_ batchId: String, mode: Mode, code: Int32, output: String) {
        if code == 0 && TaskProfiles.executionMode(for: mode) != nil {
            offerProposals(from: output, mode: mode)
            if output.contains(Self.noNewsMarker) { return }
        }
        let readsNews = [Mode.followUp, .social, .portalScanJobs, .portalScanFreelance].contains(mode)
        if code == 0 && readsNews && output.contains(Self.noNewsMarker) {
            Log(agent: AgentKind.owner(of: mode)).write("\(mode.rawValue): sin novedades")
            if batchId.hasPrefix("gm-") {
                let summary = output.replacingOccurrences(of: Self.noNewsMarker, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                reply(
                    String(localized: "Seguimientos: hoy no tocaba escribirle a nadie.\n\n")
                        + (summary.isEmpty ? String(localized: "Sin más detalle.") : String(summary.suffix(3500))))
            }
            return
        }
        guard code == 0 && !output.isEmpty else {
            let detail = output.isEmpty ? String(localized: "sin salida") : String(output.suffix(1500))
            let failure = String(localized: "\(ai.capitalizedName) terminó con error (código \(code)). Detalle: \(detail)")
            reply(failure + String(localized: "\nRegistro: workspace/ejecuciones/\(batchId).log"))
            return
        }
        reply(String(ProposalParser.removingBlock(from: output).suffix(3800)))
        switch mode {
        case .prospecting: offerProspectingEmails()
        case .profileUpdate: finishProfileUpdate()
        case .linkedInDraft:
            sendSlides(stores.batches.find(id: batchId)?.account)
        default: break
        }
    }

    func sendSlides(_ accountId: String?) {
        guard let account = stores.contentAccounts.find(accountId) else {
            reply(String(localized: "No encontré la cuenta de esta publicación en Ajustes → Cuentas de contenido."))
            return
        }
        let several = stores.contentAccounts.load().count > 1
        let publish = several ? "publica \(account.id)" : "publica"
        let change = several ? String(localized: "post \(account.id) cambia <qué>") : String(localized: "post cambia <qué>")
        let skip = several ? "post \(account.id) salta" : "post salta"
        let ask =
            String(
                localized: """
                    ¿Lo subo a \(account.title)? Responde \"\(publish)\" para subirlo tal cual, \"\(change)\" para \
                    ajustarlo\u{20}
                    """)
            + String(localized: "o \"\(skip)\" para no publicarlo.")
        media.renderSlides(for: account) { [weak self] made, failed in
            var notes: [String] = []
            if made.isEmpty {
                let aiName = self?.ai.name ?? String(localized: "la IA")
                notes.append(
                    String(localized: "Esta vez no salieron imágenes (\(aiName) no dejó las láminas o Chrome no pudo convertirlas)."))
            } else if failed > 0 {
                notes.append(String(localized: "\(failed) lámina(s) no se pudieron convertir."))
            }
            self?.notifier.sendPhotos(
                made,
                caption: String(
                    localized: """
                        \(account.title): imágenes de la publicación (\(made.count))
                        """)
            ) {
                if let text = self?.stores.contentAccounts.draftText(account) {
                    self?.reply(String(localized: "Texto de la publicación de \(account.title), listo para copiar:\n\n\(text)"))
                }
                guard account.video else {
                    self?.reply((notes + [ask]).joined(separator: " "))
                    return
                }
                self?.media.renderVideoPreview(for: account) { video, problem in
                    let rest = {
                        if let script = self?.media.readingScript(for: account) {
                            self?.stores.runState.setWaitingVoiceAccount(account.id)
                            self?.reply(script)
                        }
                        if let text = self?.stores.contentAccounts.videoDescription(account) {
                            self?.reply(String(localized: "Descripción del video de \(account.title), lista para copiar:\n\n\(text)"))
                        }
                        self?.reply(
                            (notes + [ask + String(localized: " El video se sube cuando me mandes tu voz.")]).joined(separator: " "))
                    }
                    guard let video else {
                        notes.append(
                            String(localized: "No salió la vista previa del video: \(problem ?? String(localized: "sin detalle"))."))
                        rest()
                        return
                    }
                    self?.notifier.sendVideo(video, caption: String(localized: "\(account.title): vista previa del video, sin voz")) {
                        rest()
                    }
                }
            }
        }
    }

    func offerProposals(from output: String, mode: Mode) {
        guard let execution = TaskProfiles.executionMode(for: mode) else { return }
        let proposals: [Proposal]
        switch ProposalParser.parse(output, rules: targetRules) {
        case .success(let parsed):
            proposals = parsed
        case .failure(.blockMissing):
            return
        case .failure(let failure):
            Log(agent: AgentKind.owner(of: mode)).write("\(mode.rawValue): la lista de propuestas no es válida (\(failure))")
            reply(
                String(
                    localized:
                        """
                        \(ai.capitalizedName) no dejó la lista en el formato esperado; no la muestro. El detalle quedó \
                        en el registro.
                        """))
            return
        }
        let intake = ProposalIntake(window: policy.corridas.proposalSeenWindow, rules: targetRules).accept(
            proposals,
            allowed: TaskProfiles.allowedProposals(for: mode),
            seen: stores.executionState.seenProposals(),
            now: Date()
        )
        for proposal in intake.rejected {
            log.write("\(mode.rawValue): descartada una propuesta con acción no permitida para esta tarea (\(proposal.action.rawValue))")
        }
        let fresh = intake.fresh
        guard !fresh.isEmpty else { return }
        let batch = Batch(mode: execution, items: fresh.map { BatchItem($0) }, status: .pending)
        guard offer(batch, proposals: fresh, title: Self.proposalsTitle(for: mode, count: fresh.count)) else { return }
        do {
            try stores.executionState.saveSeenProposals(intake.seen)
        } catch {
            log.write("\(mode.rawValue): no pude guardar qué propuestas ya mostré: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func offer(_ batch: Batch, proposals: [Proposal], title: String) -> Bool {
        do {
            try stores.executionState.saveProposals(proposals, batch: batch.id)
        } catch {
            log.write("\(batch.mode.rawValue): no pude guardar la copia de las propuestas: \(error.localizedDescription)")
            reply(String(localized: "No pude guardar la lista para aprobar, así que no te la muestro: \(error.localizedDescription)"))
            return false
        }
        stores.batches.upsert(batch)
        stores.metrics.bump(batch.mode, "avisados", proposals.count)
        let auto = stores.agents.load(AgentKind.owner(of: batch.mode)).autoApprove
        let footer =
            auto
            ? String(localized: "\(ai.capitalizedName) ya los está procesando; te aviso al terminar.")
            : String(localized: "Responde \"si\" para que \(ai.name) los procese, \"si 1 3\" para elegir o \"no\" para descartar.")
        notifier.announce(batch, title: title + (auto ? String(localized: " (envío automático)") : ""), footer: footer)
        if auto { autoApprove(batch) }
        return true
    }

    func finishProfileUpdate() {
        stores.profile.clearChangeRequests()
        let profile = stores.profile.load()
        guard !profile.cvVariants.isEmpty else {
            reply(String(localized: "perfil.json no tiene hojas de vida definidas (cvVariants), así que no generé PDF."))
            return
        }
        media.renderCVs(for: profile) { [weak self] result in
            for file in result.made {
                self?.notifier.sendFile(file, caption: String(localized: "Hoja de vida actualizada: \(file.lastPathComponent)"))
            }
            var lines = [String(localized: "Hojas de vida: \(result.made.count) de \(profile.cvVariants.count) listas.")]
            let aiName = self?.ai.capitalizedName ?? String(localized: "La IA")
            if !result.missing.isEmpty {
                lines.append(String(localized: "\(aiName) no dejó el HTML de: \(result.missing.joined(separator: ", "))."))
            }
            if !result.failed.isEmpty {
                lines.append(
                    String(
                        localized:
                            """
                            No pude crear el PDF de: \(result.failed.joined(separator: ", ")) (revisa que Google Chrome \
                            esté instalado).
                            """))
            }
            self?.reply(lines.joined(separator: "\n"))
        }
    }

    func offerProspectingEmails() {
        switch ExecutionApprovals.emailDrafts(rules: targetRules, pending: stores.prospecting.pendingEmails()) {
        case .none:
            return
        case .invalid(let ids):
            let numbers = ids.joined(separator: ", ")
            Log(agent: .clients).write("Prospección: correos incompletos o repetidos en pendientes.json (\(numbers))")
            reply(
                String(
                    localized:
                        """
                        \(ai.capitalizedName) dejó correos sin destinatario, asunto o texto válidos (\(numbers)); no te \
                        muestro la lista.
                        """)
            )
        case .found(let drafts):
            let batch = Batch(mode: .prospectingSend, items: drafts.map { BatchItem($0.proposal, kind: $0.kind) }, status: .pending)
            offer(batch, proposals: drafts.map(\.proposal), title: String(localized: "Correos de hoy: \(drafts.count) para aprobar"))
        }
    }

    static func proposalsTitle(for mode: Mode, count: Int) -> String {
        switch mode {
        case .social: return String(localized: "Redes: \(count) publicación(es) con vacantes para ti")
        case .followUp: return String(localized: "Seguimientos: \(count) para aprobar")
        case .portalScanFreelance: return String(localized: "Tus portales: \(count) proyecto(s) para ti")
        default: return String(localized: "Tus portales: \(count) vacante(s) para ti")
        }
    }
}
