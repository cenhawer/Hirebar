import Foundation
import HirebarDomain

private let log = Log(.telegram)

extension Controller {
    nonisolated static let help = String(
        localized: """
            Comandos:
            si: la IA envía/postula a toda la última lista
            si 1 3: solo esos números
            no: descarta la lista
            estado: cupos, próximas búsquedas y qué está haciendo la IA
            buscar: busca proyectos y vacantes ya (o "buscar freelance", "buscar empleo")
            seguimientos: revisa y hace seguimientos ahora
            informe: arma ya el informe semanal
            anota <texto>: guarda algo para el informe (ej: anota entrevista el jueves)
            post: arma ya una publicación con imágenes para cada cuenta de contenido (te llega aquí antes de subirla)
            post <cuenta>: solo para esa cuenta (ej: post empresa)
            publica <cuenta>: sube la publicación que te mandé (con una sola cuenta basta "publica")
            post <cuenta> cambia <qué>: la rehace con tu cambio · post <cuenta> salta: la descarta
            video <cuenta>: vuelve a mandar la vista previa sin voz y el guion para grabar
            (nota de voz): leyendo el guion; te devuelvo el video con tu voz, listo para subir
            rearmar <cuenta>: rehace el video con la última nota de voz que mandaste
            envia correos: envía la lista de correos del día (o "envia correos 1 3", String(localized: "no correos"))
            logro <texto>: agrega un logro a tu perfil y regenera tus hojas de vida
            trabajo <texto>: registra un cambio de trabajo (ej: trabajo nuevo Backend Senior en Acme desde dic 2026)
            habilidad <nombre> <domino|conozco|evito>: cambia una habilidad; afecta búsquedas y filtros al instante
            habilidades: muestra tus habilidades por nivel
            hv: regenera tus hojas de vida sin cambios
            agentes: estado de cada agente (empleo, freelance, clientes, contenido, perfil, analista)
            agente <nombre> on / off: prende o apaga un agente
            corre <nombre>: corre ya las tareas de un agente (ej: corre clientes)
            reanudar <nombre>: saca un agente de la pausa por una acción que no coincidió con lo aprobado
            auto si / auto no: envío automático de empleo y freelance (o String(localized: "auto <agente> si"), ej: String(localized: "auto clientes si"))
            (Puedes responder citando un aviso para elegir cuál lista.)
            """)

    nonisolated static let callbackAnswer = String(localized: "Recibido")
    nonisolated static let missingVocabulary =
        String(localized: "Faltan los comandos dentro de la app (comandos.json). Vuelve a instalarla con scripts/bundle.sh --install.")

    func handle(_ message: ChatMessage) {
        guard admits(message) else { return }
        if let callback = message.callbackId { chat.answerCallback(callback, text: Self.callbackAnswer) }
        guard let parser = commandParser else {
            reply(Self.missingVocabulary)
            return
        }
        let command = parser.parse(
            CommandInput(
                text: message.text, isButton: message.callbackId != nil, replyTo: message.replyTo, hasAudio: message.audioFileId != nil))
        if command.kind == .voiceNote, let fileId = message.audioFileId {
            handleRecording(fileId: fileId, ext: message.audioExtension, size: (message.audioBytes, message.audioSeconds))
            return
        }
        perform(command)
    }

    func list(for target: ListTarget) -> Batch? {
        switch target {
        case .batch(let id): return stores.batches.find(id: id)
        case .reply(let messageId): return stores.batches.find(messageId: messageId) ?? stores.batches.latestPending()
        case .emails: return latestPendingEmails()
        case .latest: return stores.batches.latestPending()
        }
    }

    func perform(_ command: ParsedCommand) {
        switch command.kind {
        case .approve, .discard, .status, .agents, .resume, .keepPaused, .autoSend, .autoSendConfirm, .autoSendCancel:
            performControl(command)
        case .followUps, .weeklyReport, .regenerateCV, .note, .agentSwitch, .runAgent, .search, .practice:
            performRoutine(command)
        case .publish, .post, .video, .remake: performContent(command)
        case .achievement, .jobChange, .skill, .skills: performProfile(command)
        case .voiceNote, .help: reply(Self.help)
        }
    }

    func performControl(_ command: ParsedCommand) {
        switch command.kind {
        case .approve: approve(list(for: command.target), picks: command.numbers)
        case .discard: discardList(list(for: command.target))
        case .status: reply(statusReport())
        case .agents: reply(agentsReport())
        case .resume: resumeAgent(named: command.argument ?? command.rest)
        case .keepPaused: keepPaused(named: command.argument ?? "")
        case .autoSend: handleAuto(command.words)
        case .autoSendConfirm: confirmAutoSend(command.argument ?? "")
        case .autoSendCancel: reply(String(localized: "Listo, el envío automático sigue como estaba."))
        default: reply(Self.help)
        }
    }

    func performRoutine(_ command: ParsedCommand) {
        switch command.kind {
        case .followUps: runScheduled(.followUp, manual: true)
        case .weeklyReport: runScheduled(.weeklyReport, manual: true)
        case .regenerateCV: runScheduled(.profileUpdate, manual: true)
        case .note: takeNote(command.rest)
        case .agentSwitch: handleAgentSwitch(command.words)
        case .runAgent: handleRunNow(command.rest)
        case .search: searchNow(command.words.first ?? "")
        case .practice: handlePractice(command.words)
        default: reply(Self.help)
        }
    }

    func performContent(_ command: ParsedCommand) {
        switch command.kind {
        case .publish:
            switch draftAccount(named: command.words.first, verb: "publica") {
            case .found(let account): runScheduled(.linkedInPublish, manual: true, account: account.id)
            case .problem(let text): reply(text)
            }
        case .post: handlePost(command.rest)
        case .video: rebuildVideo(command.words.first)
        case .remake: remakeWithLastRecording(command.words.first)
        default: reply(Self.help)
        }
    }

    func performProfile(_ command: ParsedCommand) {
        switch command.kind {
        case .achievement:
            requestProfileChange("Logro", command.rest, example: String(localized: "logro bajé el costo de AWS 20% en Acme"))
        case .jobChange:
            requestProfileChange(
                String(localized: "Cambio de trabajo"), command.rest,
                example: String(localized: "trabajo nuevo Backend Senior en Acme desde dic 2026"))
        case .skill: handleSkill(command.rest)
        case .skills: reply(stores.profile.load().summary)
        default: reply(Self.help)
        }
    }

    nonisolated static let practiceOrigin = "Telegram"

    func handlePractice(_ words: [String]) {
        let named = words.count > 1 ? stores.agents.parse(words.dropLast().joined(separator: " ")) : nil
        if let named, let value = words.last, ["si", "on", "no", "off"].contains(value) {
            Practice.set(named, on: value == "si" || value == "on", from: Self.practiceOrigin, agents: stores.agents)
        }
        let lines = AgentKind.allCases.map {
            String(
                localized: "\(stores.agents.load($0).name): \(stores.agents.load($0).practice ? String(localized: "en práctica") : "real")")
        }
        reply(
            String(localized: "Modo práctica · ") + lines.joined(separator: " · ")
                + String(localized: "\nCambiar: \"practica empleo si\", \"practica empleo no\"."))
    }

    func takeNote(_ note: String) {
        guard !note.isEmpty else {
            reply(String(localized: "Escribe qué anotar, por ejemplo: anota entrevista el jueves"))
            return
        }
        stores.metrics.event(note)
        reply(String(localized: "Anotado para el informe del domingo."))
    }

    func searchNow(_ scope: String) {
        if scope != "empleo" { freelanceRadar?.checkNow() }
        if scope != "freelance" { jobRadar?.checkNow() }
        reply(String(localized: "Buscando ahora; si encuentro algo te aviso."))
    }
}
