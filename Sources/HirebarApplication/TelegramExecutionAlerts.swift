import Foundation
import HirebarDomain

private let log = Log(.telegram)

@MainActor
struct TelegramExecutionAlerts: ExecutionAlerts {
    let notifier: Notifier
    let agents: AgentRepository

    func executionNeedsReview(agent: AgentID, verification: ExecutionVerification, pauseSaved: Bool) {
        let name = AgentKind(rawValue: agent.rawValue).map { agents.load($0).name } ?? agent.rawValue
        let text = Self.message(agentName: name, alias: agent.rawValue, verification: verification, pauseSaved: pauseSaved)
        log.write("Verificación: \(name) en pausa por la lista \(verification.batch)")
        guard notifier.canUseTelegram else {
            notifier.tell(text)
            return
        }
        let resume = (String(localized: "Reanudar \(name)"), "resume:\(agent.rawValue)")
        let keep = (String(localized: "Mantener en pausa"), "keep:\(agent.rawValue)")
        notifier.chat.send(text, chatId: notifier.chatId, buttons: [[resume, keep]])
    }

    nonisolated static func message(agentName: String, alias: String, verification: ExecutionVerification, pauseSaved: Bool) -> String {
        let opening = String(
            localized: """
                \(agentName) quedó en pausa: revisé la lista \(verification.batch) y algo no coincide con lo \
                que aprobaste.
                """)
        var lines = [opening]
        if let reason = verification.unverifiedReason {
            lines.append(unverifiedText(reason))
        }
        for verdict in verification.violations {
            let target = verdict.record.map { $0.target.displayText } ?? ""
            lines.append(String(localized: "• \(verdict.record?.action.rawValue ?? "") en \(target): \(violationText(verdict.reason))"))
        }
        if !pauseSaved {
            lines.append(String(localized: "No pude guardar la pausa en el disco: sigue en pausa mientras Hirebar esté abierto."))
        }
        lines.append(
            String(
                localized: """
                    No ejecuto más listas de \(agentName) hasta que respondas. Escribe \"reanudar \(alias)\" o usa \
                    los botones.
                    """)
        )
        return lines.joined(separator: "\n")
    }

    nonisolated static func unverifiedText(_ reason: UnverifiedReason) -> String {
        switch reason {
        case .logMissing: return String(localized: "La IA no dejó el registro de lo que hizo, así que no puedo confirmar qué se envió.")
        case .logInvalid: return String(localized: "El registro de lo que hizo la IA no se puede leer.")
        case .batchMismatch: return String(localized: "El registro de lo que hizo la IA es de otra lista.")
        }
    }

    nonisolated static func violationText(_ reason: ViolationReason?) -> String {
        switch reason {
        case .notApproved: return String(localized: "no estaba en lo que aprobaste")
        case .actionMismatch: return String(localized: "hizo una acción distinta de la aprobada")
        case .targetMismatch: return String(localized: "lo mandó a otro destino")
        case .textMismatch: return String(localized: "el texto no es el que aprobaste")
        case .repeated: return String(localized: "lo hizo más de una vez")
        case nil: return String(localized: "no coincide")
        }
    }
}
