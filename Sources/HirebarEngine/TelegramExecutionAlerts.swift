import Foundation
import HirebarApplication
import HirebarCore
import HirebarDomain

struct TelegramExecutionAlerts: ExecutionAlerts {
    func executionNeedsReview(agent: AgentID, verification: ExecutionVerification, pauseSaved: Bool) {
        let name = AgentKind(rawValue: agent.rawValue).map { AgentStore.load($0).name } ?? agent.rawValue
        let text = Self.message(agentName: name, alias: agent.rawValue, verification: verification, pauseSaved: pauseSaved)
        Log.write("Verificación: \(name) en pausa por la lista \(verification.batch)")
        guard Notifier.canUseTelegram else {
            Notifier.tell(text)
            return
        }
        Telegram.shared.send(
            text, chatId: Config.load().chatId,
            buttons: [[("Reanudar \(name)", "resume:\(agent.rawValue)"), ("Mantener en pausa", "keep:\(agent.rawValue)")]])
    }

    static func message(agentName: String, alias: String, verification: ExecutionVerification, pauseSaved: Bool) -> String {
        var lines = ["\(agentName) quedó en pausa: revisé la lista \(verification.batch) y algo no coincide con lo que aprobaste."]
        if let reason = verification.unverifiedReason {
            lines.append(unverifiedText(reason))
        }
        for verdict in verification.violations {
            let target = verdict.record.map { $0.target.displayText } ?? ""
            lines.append("• \(verdict.record?.action.rawValue ?? "") en \(target): \(violationText(verdict.reason))")
        }
        if !pauseSaved {
            lines.append("No pude guardar la pausa en el disco: sigue en pausa mientras Hirebar esté abierto.")
        }
        lines.append("No ejecuto más listas de \(agentName) hasta que respondas. Escribe \"reanudar \(alias)\" o usa los botones.")
        return lines.joined(separator: "\n")
    }

    static func unverifiedText(_ reason: UnverifiedReason) -> String {
        switch reason {
        case .logMissing: return "La IA no dejó el registro de lo que hizo, así que no puedo confirmar qué se envió."
        case .logInvalid: return "El registro de lo que hizo la IA no se puede leer."
        case .batchMismatch: return "El registro de lo que hizo la IA es de otra lista."
        }
    }

    static func violationText(_ reason: ViolationReason?) -> String {
        switch reason {
        case .notApproved: return "no estaba en lo que aprobaste"
        case .actionMismatch: return "hizo una acción distinta de la aprobada"
        case .targetMismatch: return "lo mandó a otro destino"
        case .textMismatch: return "el texto no es el que aprobaste"
        case .repeated: return "lo hizo más de una vez"
        case nil: return "no coincide"
        }
    }
}
