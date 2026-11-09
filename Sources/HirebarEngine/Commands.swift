import Foundation
import HirebarCore
import HirebarDomain

extension Controller {
    static let help = """
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
        envia correos: envía la lista de correos del día (o "envia correos 1 3", "no correos")
        logro <texto>: agrega un logro a tu perfil y regenera tus hojas de vida
        trabajo <texto>: registra un cambio de trabajo (ej: trabajo nuevo Backend Senior en Acme desde dic 2026)
        habilidad <nombre> <domino|conozco|evito>: cambia una habilidad; afecta búsquedas y filtros al instante
        habilidades: muestra tus habilidades por nivel
        hv: regenera tus hojas de vida sin cambios
        agentes: estado de cada agente (empleo, freelance, clientes, contenido, perfil, analista)
        agente <nombre> on / off: prende o apaga un agente
        corre <nombre>: corre ya las tareas de un agente (ej: corre clientes)
        reanudar <nombre>: saca un agente de la pausa por una acción que no coincidió con lo aprobado
        auto si / auto no: envío automático de empleo y freelance (o "auto <agente> si", ej: "auto clientes si")
        (Puedes responder citando un aviso para elegir cuál lista.)
        """

    static let approveVerbs: Set<String> = ["si", "dale", "ok", "listo", "envia", "enviar", "postula", "aplica"]
    static let emailVerbs: Set<String> = ["envia", "enviar", "envialos", "envie", "si", "dale", "ok", "no", "aprobado", "aprueba"]

    func handle(_ message: TelegramMessage) {
        guard admits(message) else { return }
        let config = Config.load()
        if let fileId = message.audioFileId {
            handleRecording(fileId: fileId, ext: message.audioExtension)
            return
        }

        var text = message.text.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var batch: Batch?
        var callbackArgument: String?
        if let callback = message.callbackId {
            Telegram.shared.answerCallback(callback, text: "Recibido")
            if let colon = text.firstIndex(of: ":") {
                callbackArgument = String(text[text.index(after: colon)...])
                batch = BatchStore.find(id: callbackArgument ?? "")
                text = String(text[..<colon])
            }
        }
        if batch == nil, let replyTo = message.replyTo { batch = BatchStore.find(messageId: replyTo) }

        let words = text.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let verb = words.first ?? ""
        let numbers = words.compactMap { Int($0) }
        if (words.contains("correos") || words.contains("correo")) && Self.emailVerbs.contains(verb) {
            handleEmails(verb: verb, numbers: numbers)
            return
        }
        switch verb {
        case _ where Self.approveVerbs.contains(verb):
            approve(batch ?? BatchStore.latestPending(), picks: numbers)
        case "no", "descarta", "nada":
            discard(batch ?? BatchStore.latestPending(), chatId: config.chatId)
        case "estado":
            reply(statusReport())
        case "reanudar", "resume":
            resumeAgent(named: callbackArgument ?? rest(of: message.text))
        case "keep":
            keepPaused(named: callbackArgument ?? "")
        case "seguimientos", "seguimiento":
            runScheduled(.followUp, manual: true)
        case "informe":
            runScheduled(.weeklyReport, manual: true)
        case "anota", "anotar", "nota":
            let note = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: " ", maxSplits: 1).dropFirst().first.map(String.init) ?? ""
            guard !note.isEmpty else {
                reply("Escribe qué anotar, por ejemplo: anota entrevista el jueves")
                return
            }
            Metrics.event(note)
            reply("Anotado para el informe del domingo.")
        case "autoon":
            confirmAutoSend(callbackArgument ?? "")
        case "autocancel":
            reply("Listo, el envío automático sigue como estaba.")
        case "auto", "automatico":
            handleAuto(Array(words.dropFirst()))
        case "agentes":
            reply(agentsReport())
        case "agente":
            handleAgentSwitch(Array(words.dropFirst()))
        case "corre", "correr":
            handleRunNow(rest(of: message.text))
        case "publica", "publicar":
            switch draftAccount(named: words.dropFirst().first, verb: "publica") {
            case .found(let account): runScheduled(.linkedInPublish, manual: true, account: account.id)
            case .problem(let text): reply(text)
            }
        case "post":
            handlePost(message.text)
        case "video":
            rebuildVideo(words.dropFirst().first)
        case "rearmar", "rehacer":
            remakeWithLastRecording(words.dropFirst().first)
        case "logro", "logros":
            requestProfileChange("Logro", rest(of: message.text), example: "logro bajé el costo de AWS 20% en Acme")
        case "trabajo":
            requestProfileChange("Cambio de trabajo", rest(of: message.text), example: "trabajo nuevo Backend Senior en Acme desde dic 2026")
        case "habilidad", "skill":
            handleSkill(rest(of: message.text))
        case "habilidades", "skills":
            reply(Profile.load().summary)
        case "hv":
            runScheduled(.profileUpdate, manual: true)
        case "buscar":
            let target = words.dropFirst().first ?? ""
            if target != "empleo" { FreelanceRadar.shared.checkNow() }
            if target != "freelance" { JobRadar.shared.checkNow() }
            reply("Buscando ahora; si encuentro algo te aviso.")
        default:
            reply(Self.help)
        }
    }

    public func sendTestMessage() {
        Notifier.tell("Aviso de prueba: tu celular ya recibe Hirebar.\n\n" + statusReport())
    }

    public static var welcome: String {
        "Listo, este chat quedó vinculado a Hirebar y solo atiende tu cuenta. Te avisaré aquí cada vez que aparezcan "
            + "proyectos o vacantes para ti.\n\n" + help
    }

    static let pairingReply = "Recibido. Confirma tu nombre en la Mac, en Ajustes → Telegram y avisos."

    func admits(_ message: TelegramMessage) -> Bool {
        guard let sender = message.sender else {
            Log.write("Telegram: ignorado un mensaje sin remitente")
            return false
        }
        guard Config.load().channelOwner != nil else {
            if channel.offer(sender, text: message.text) {
                Telegram.shared.send(Self.pairingReply, chatId: sender.chatId)
            } else {
                Log.write("Telegram: ignorado un mensaje fuera de la vinculación")
            }
            return false
        }
        switch channel.admit(sender) {
        case .allowed:
            return true
        case .notOwner:
            Log.write("Telegram: ignorado un mensaje de otra cuenta")
            return false
        case .tooMany:
            Log.write("Telegram: ignorado un mensaje por superar el límite por minuto")
            return false
        }
    }

    public func statusReport() -> String {
        """
        \(AI.capitalizedName): \(status)
        Cupos: \(Quotas.summary())
        Búsqueda freelance: \(FreelanceRadar.shared.status)
        Búsqueda de empleo: \(JobRadar.shared.status)

        \(agentsReport())
        """
    }

    public func pauseReason(of kind: AgentKind) -> String? {
        pauseReason(of: kind, among: executionGuard.pauses())
    }

    public func pauseReasons() -> [AgentKind: String] {
        let pauses = executionGuard.pauses()
        let reasons = AgentKind.allCases.compactMap { kind in pauseReason(of: kind, among: pauses).map { (kind, $0) } }
        return Dictionary(uniqueKeysWithValues: reasons)
    }

    func pauseReason(of kind: AgentKind, among pauses: [AgentPause]) -> String? {
        let agent = AgentID(rawValue: kind.rawValue)
        return (pauses.first { $0.agent == agent } ?? unsavedPauses[agent]).map { "lista \($0.batch) (\($0.reason))" }
    }

    @discardableResult
    public func resumeAgent(_ kind: AgentKind) -> Bool {
        let agent = AgentID(rawValue: kind.rawValue)
        guard activePause(of: agent) != nil else { return false }
        unsavedPauses[agent] = nil
        do {
            try executionGuard.resume(agent)
            Log.write("Verificación: \(AgentStore.load(kind).name) reanudado por la persona")
            return true
        } catch {
            Log.write("Verificación: no pude reanudar \(kind.rawValue): \(error.localizedDescription)")
            return false
        }
    }

    func resumeAgent(named name: String) {
        guard let kind = AgentKind.parse(name) else {
            reply("Escribe: reanudar <empleo | freelance | clientes | contenido | perfil | analista>")
            return
        }
        let agentName = AgentStore.load(kind).name
        if resumeAgent(kind) {
            let since = Date().addingTimeInterval(-24 * 3600)
            let waiting = BatchStore.load().filter {
                $0.status == .pending && $0.created > since && AgentKind.owner(of: $0.mode) == kind && $0.mode.hasItems
            }
            let lists = waiting.map(\.id).joined(separator: ", ")
            let pending = "Estas listas siguen pendientes y no se ejecutan solas: \(lists). Responde \"si\" a cada una para ejecutarla."
            reply(waiting.isEmpty ? "\(agentName) reanudado." : "\(agentName) reanudado. \(pending)")
        } else {
            reply("\(agentName) no estaba en pausa.")
        }
    }

    func keepPaused(named name: String) {
        guard let kind = AgentKind.parse(name) else {
            reply("El agente sigue en pausa.")
            return
        }
        reply("\(AgentStore.load(kind).name) sigue en pausa. Escribe \"reanudar \(kind.rawValue)\" cuando quieras.")
    }

    private func rest(of raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 1).dropFirst().first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func requestProfileChange(_ kind: String, _ text: String, example: String) {
        guard !text.isEmpty else {
            reply("Escribe el detalle, por ejemplo: \(example)")
            return
        }
        ProfileRequests.append(kind, text)
        runScheduled(.profileUpdate, manual: true)
    }

    private func handleSkill(_ text: String) {
        var parts = text.split(separator: " ").map(String.init)
        guard parts.count >= 2, let level = SkillLevel.parse(parts.removeLast()) else {
            if !text.isEmpty, let skill = Profile.load().skill(named: text) {
                reply("\(skill.name): \(skill.level.rawValue)")
            } else {
                reply("Escribe: habilidad <nombre> <domino|conozco|evito>, por ejemplo: habilidad Go conozco")
            }
            return
        }
        let name = parts.joined(separator: " ")
        switch ProfileEditor.setSkill(name, level: level) {
        case .added:
            reply("Agregué \(name) como \(level.rawValue). Ya cuenta en la próxima búsqueda.")
        case .updated(let from):
            reply("\(name): \(from.rawValue) → \(level.rawValue). Ya cuenta en la próxima búsqueda.")
        case .unchanged:
            reply("\(name) ya estaba como \(level.rawValue).")
        case .failed(let reason):
            reply("No pude cambiar la habilidad: \(reason)")
        }
    }

    private func discard(_ found: Batch?, chatId: Int64) {
        guard var target = found, target.status == .pending else {
            reply("No tengo listas pendientes.")
            return
        }
        target.status = .discarded
        BatchStore.upsert(target)
        Metrics.bump(target.mode, "listas_descartadas")
        if let id = target.messageId { Telegram.shared.removeButtons(chatId: chatId, messageId: id) }
        reply("Descartada. Sigo buscando.")
    }

    private func handleEmails(verb: String, numbers: [Int]) {
        let since = Date().addingTimeInterval(-24 * 3600)
        let emails = BatchStore.load().filter { $0.mode == .prospectingSend && $0.status == .pending && $0.created > since }
            .max { $0.created < $1.created }
        guard let emails else {
            reply("No tengo correos pendientes de aprobar.")
            return
        }
        if verb == "no" {
            discard(emails, chatId: Config.load().chatId)
            let pending = Paths.prospecting.appendingPathComponent("pendientes.json")
            let stamp = Int(Date().timeIntervalSince1970)
            try? FileManager.default.moveItem(at: pending, to: Paths.prospecting.appendingPathComponent("descartados-\(stamp).json"))
            return
        }
        approve(emails, picks: numbers)
    }

    static let autoSendOrigin = "Telegram"

    private func handleAuto(_ rest: [String]) {
        let named = rest.count > 1 ? AgentKind.parse(rest.dropLast().joined(separator: " ")) : nil
        let targets: [AgentKind] = (named.map { [$0] } ?? [.jobs, .freelance]).filter(AutoSend.agents.contains)
        if let value = rest.last, ["si", "on"].contains(value) {
            let pending = targets.filter { !AgentStore.load($0).autoApprove }
            if !pending.isEmpty {
                askToTurnOnAutoSend(pending)
                return
            }
        }
        if let value = rest.last, ["no", "off"].contains(value) {
            for kind in targets { AutoSend.turnOff(kind, from: Self.autoSendOrigin) }
        }
        let lines = [AgentKind.jobs, .freelance, .clients].map { kind -> String in
            let agent = AgentStore.load(kind)
            return "\(agent.name): \(agent.autoApprove ? "SÍ" : "no")"
        }
        reply("Envío automático · " + lines.joined(separator: " · ") + "\nCambiar: \"auto si\", \"auto no\", \"auto empleo no\", \"auto clientes si\".")
    }

    func askToTurnOnAutoSend(_ kinds: [AgentKind]) {
        let names = kinds.map(\.rawValue).joined(separator: ",")
        questions(
            AutoSend.explanation(for: kinds) + "\n\n¿Lo prendo?",
            [[("Sí, prender", "autoon:\(names)"), ("No", "autocancel:\(names)")]])
    }

    func confirmAutoSend(_ names: String) {
        let kinds = names.split(separator: ",").compactMap { AgentKind(rawValue: String($0)) }.filter(AutoSend.agents.contains)
        guard !kinds.isEmpty else { return }
        for kind in kinds { AutoSend.turnOn(kind, from: Self.autoSendOrigin) }
        reply("Envío automático prendido: " + kinds.map { AgentStore.load($0).name }.joined(separator: ", ") + ".")
    }

    private func handleAgentSwitch(_ rest: [String]) {
        guard let value = rest.last, ["on", "off", "si", "no"].contains(value),
              let kind = AgentKind.parse(rest.dropLast().joined(separator: " ")) else {
            reply("Escribe: agente <nombre> on / off, por ejemplo: agente clientes off")
            return
        }
        let on = value == "on" || value == "si"
        AgentStore.update(kind) { $0.enabled = on }
        reply("\(AgentStore.load(kind).name): \(on ? "prendido" : "apagado").")
    }

    private func handleRunNow(_ name: String) {
        guard let kind = AgentKind.parse(name) else {
            reply("Escribe: corre <empleo | freelance | clientes | contenido | perfil | analista>")
            return
        }
        runAgentNow(kind)
    }

    public func runAgentNow(_ kind: AgentKind) {
        let agent = AgentStore.load(kind)
        switch kind {
        case .jobs: JobRadar.shared.checkNow()
        case .freelance: FreelanceRadar.shared.checkNow()
        default: break
        }
        if kind == .profile {
            runScheduled(.profileUpdate, manual: true)
        } else {
            for task in agent.tasks { runScheduled(task.mode, manual: true) }
        }
        if agent.tasks.isEmpty && !agent.hasSearch && kind != .profile {
            reply("\(agent.name) no tiene tareas configuradas.")
        } else if agent.hasSearch {
            reply("\(agent.name): buscando ahora.")
        }
    }

    public func agentsReport() -> String {
        AgentStore.all().map { agent in
            var line = "\(agent.name): \(agent.enabled ? "prendido" : "apagado")"
            if agent.enabled {
                if [.jobs, .freelance, .clients].contains(agent.id) { line += " · auto \(agent.autoApprove ? "sí" : "no")" }
                if let next = Scheduler.shared.nextRun(of: agent.id) { line += " · próxima \(TextTools.countdown(next))" }
                if let reason = pauseReason(of: agent.id) { line += " · en pausa: \(reason)" }
            }
            return line
        }.joined(separator: "\n")
    }

    enum AccountLookup {
        case found(ContentAccount)
        case problem(String)
    }

    /// Cuenta a la que se refiere un comando sobre un borrador: la nombrada, o la única que tiene borrador.
    func draftAccount(named word: String?, verb: String, suffix: String = "") -> AccountLookup {
        if let word, let account = ContentAccountStore.match(word) {
            return account.hasDraft ? .found(account)
                : .problem("\(account.title) no tiene publicación pendiente. Escribe \"post \(account.id)\" para armar una.")
        }
        let pending = ContentAccountStore.load().filter(\.hasDraft)
        switch pending.count {
        case 0: return .problem("No tengo publicaciones pendientes. Escribe \"post\" para que arme una.")
        case 1: return .found(pending[0])
        default:
            let names = pending.map { "\(verb) \($0.id)\(suffix)" }.joined(separator: " · ")
            return .problem("Hay publicaciones pendientes en varias cuentas. Dime cuál: \(names)")
        }
    }

    /// Vuelve a mandar la vista previa sin voz y el guion para grabar.
    private func rebuildVideo(_ word: String?) {
        let withScenes = ContentAccountStore.load().filter {
            FileManager.default.fileExists(atPath: $0.videoFolder.appendingPathComponent("guion.json").path)
        }
        let account: ContentAccount
        if let word, let named = ContentAccountStore.match(word) {
            account = named
        } else if withScenes.count == 1 {
            account = withScenes[0]
        } else if withScenes.isEmpty {
            reply("No hay escenas de video guardadas. Escribe \"post <cuenta>\" con el video prendido en esa cuenta.")
            return
        } else {
            reply("¿De cuál cuenta? " + withScenes.map { "video \($0.id)" }.joined(separator: " · "))
            return
        }
        reply("Armando la vista previa del video de \(account.title); tarda unos minutos.")
        ReelRenderer.renderPreview(account) { [weak self] video, problem in
            let sendScript = {
                if let script = ReelRenderer.readingScript(account) {
                    UserDefaults.standard.set(account.id, forKey: Controller.waitingVoiceKey)
                    self?.reply(script)
                }
            }
            guard let video else {
                self?.reply("No salió la vista previa: \(problem ?? "sin detalle").")
                sendScript()
                return
            }
            Notifier.sendVideo(video, caption: "\(account.title): vista previa del video, sin voz") { sendScript() }
        }
    }

    /// Rehace el video con la última nota de voz guardada de la cuenta.
    private func remakeWithLastRecording(_ word: String?) {
        let accounts = ContentAccountStore.load()
        let waiting = ContentAccountStore.find(UserDefaults.standard.string(forKey: Controller.waitingVoiceKey))
        guard let account = word.flatMap(ContentAccountStore.match) ?? waiting ?? accounts.first(where: \.video) else {
            reply("No sé de qué cuenta. Escribe: rearmar <cuenta>")
            return
        }
        let files = (try? FileManager.default.contentsOfDirectory(at: account.videoFolder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        guard let recording = files.filter({ $0.lastPathComponent.hasPrefix("grabacion.") }).max(by: {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a < b
        }) else {
            reply("No tengo una nota de voz guardada de \(account.title). Mándame una leyendo el guion.")
            return
        }
        reply("Rehaciendo el video de \(account.title) con tu última nota de voz; tarda unos minutos.")
        deliverVoiced(account, recording: recording)
    }

    /// Arma el video con la grabación y lo manda con su descripción.
    private func deliverVoiced(_ account: ContentAccount, recording: URL) {
        ReelRenderer.renderWithVoice(account, recording: recording) { [weak self] video, problem in
            guard let video else {
                self?.reply("No pude armar el video con tu voz: \(problem ?? "sin detalle"). Puedes mandar el audio otra vez.")
                return
            }
            Notifier.sendVideo(video, caption: "\(account.title): video con tu voz, listo para subir") {
                if let text = Controller.copyText(account.videoFolder.appendingPathComponent("texto.md")) {
                    self?.reply("Descripción del video de \(account.title), lista para copiar:\n\n\(text)")
                }
                let several = ContentAccountStore.load().count > 1
                self?.reply("¿Lo subo? Responde \"\(several ? "publica \(account.id)" : "publica")\" para subir el carrusel y este video. "
                            + "Si quieres repetir la grabación, manda otra nota de voz.")
            }
        }
    }

    /// La persona mandó una nota de voz: se une con el video que está esperando voz.
    func handleRecording(fileId: String, ext: String) {
        let waiting = UserDefaults.standard.string(forKey: Controller.waitingVoiceKey)
        let candidates = ContentAccountStore.load().filter {
            $0.video && FileManager.default.fileExists(atPath: $0.videoFolder.appendingPathComponent("guion.json").path)
        }
        guard let account = ContentAccountStore.find(waiting) ?? candidates.first else {
            reply("Recibí tu audio, pero no tengo ningún video esperando voz. Escribe \"post <cuenta>\" con el video prendido.")
            return
        }
        reply("Recibí tu audio. Armo el video de \(account.title) con tu voz; tarda unos minutos.")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let file = account.videoFolder.appendingPathComponent("grabacion.\(ext)")
            guard Telegram.shared.download(fileId: fileId, to: file) else {
                DispatchQueue.main.async { self?.reply("No pude descargar tu audio de Telegram. Mándalo otra vez.") }
                return
            }
            DispatchQueue.main.async { self?.deliverVoiced(account, recording: file) }
        }
    }

    private func handlePost(_ raw: String) {
        var parts = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ", maxSplits: 3).map(String.init)
        parts.removeFirst()
        var named: ContentAccount?
        if let first = parts.first, let account = ContentAccountStore.match(first) {
            named = account
            parts.removeFirst()
        }
        let sub = parts.first?.lowercased() ?? ""
        Paths.ensure()
        guard sub == "salta" || sub == "no" || sub == "cambia" else {
            runScheduled(.linkedInDraft, manual: true, account: named?.id)
            return
        }
        let account: ContentAccount
        switch draftAccount(named: named?.id, verb: "post", suffix: sub == "cambia" ? " cambia <qué>" : " salta") {
        case .found(let found): account = found
        case .problem(let text):
            reply(text)
            return
        }
        if sub == "cambia" {
            let note = parts.dropFirst().joined(separator: " ")
            try? note.write(to: account.changes, atomically: true, encoding: .utf8)
            runScheduled(.linkedInDraft, manual: true, account: account.id)
            return
        }
        let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
        try? FileManager.default.moveItem(at: account.draft,
                                          to: account.folder.appendingPathComponent("descartado-\(stamp)-\(Int(Date().timeIntervalSince1970)).md"))
        reply("Listo, no se publica en \(account.title). Escribe \"post \(account.id)\" cuando quieras otra.")
    }
}
