import Foundation
import HirebarDomain

private let log = Log(.telegram)

extension Controller {
    public func sendTestMessage() {
        notifier.tell("Aviso de prueba: tu celular ya recibe Hirebar.\n\n" + statusReport())
    }

    public static var welcome: String {
        "Listo, este chat quedó vinculado a Hirebar y solo atiende tu cuenta. Te avisaré aquí cada vez que aparezcan "
            + "proyectos o vacantes para ti.\n\n" + help
    }

    nonisolated static let pairingReply = "Recibido. Confirma tu nombre en la Mac, en Ajustes → Telegram y avisos."

    func admits(_ message: ChatMessage) -> Bool {
        guard let sender = message.sender else {
            log.write("Telegram: ignorado un mensaje sin remitente")
            return false
        }
        guard stores.config.load().channelOwner != nil else {
            if channel.offer(sender, text: message.text) {
                chat.send(Self.pairingReply, chatId: sender.chatId)
            } else {
                log.write("Telegram: ignorado un mensaje fuera de la vinculación")
            }
            return false
        }
        switch channel.admit(sender) {
        case .allowed:
            return true
        case .notOwner:
            log.write("Telegram: ignorado un mensaje de otra cuenta")
            return false
        case .tooMany:
            log.write("Telegram: ignorado un mensaje por superar el límite por minuto")
            return false
        }
    }

    public func statusReport() -> String {
        """
        \(ai.capitalizedName): \(status)
        Cupos: \(stores.quotas.summary())
        Búsqueda freelance: \(freelanceRadar?.status ?? "")
        Búsqueda de empleo: \(jobRadar?.status ?? "")

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
            log.write("Verificación: \(stores.agents.load(kind).name) reanudado por la persona")
            return true
        } catch {
            log.write("Verificación: no pude reanudar \(kind.rawValue): \(error.localizedDescription)")
            return false
        }
    }

    func resumeAgent(named name: String) {
        guard let kind = stores.agents.parse(name) else {
            reply("Escribe: reanudar <empleo | freelance | clientes | contenido | perfil | analista>")
            return
        }
        let agentName = stores.agents.load(kind).name
        if resumeAgent(kind) {
            let since = Date().addingTimeInterval(-24 * 3600)
            let waiting = stores.batches.load().filter {
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
        guard let kind = stores.agents.parse(name) else {
            reply("El agente sigue en pausa.")
            return
        }
        reply("\(stores.agents.load(kind).name) sigue en pausa. Escribe \"reanudar \(kind.rawValue)\" cuando quieras.")
    }
}
