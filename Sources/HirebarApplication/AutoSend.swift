import Foundation
import HirebarDomain

public enum AutoSend {
    public static let agents: [AgentKind] = [.jobs, .freelance, .clients]

    static func whatItDoes(_ kind: AgentKind) -> String {
        switch kind {
        case .jobs: return String(localized: "postula a las vacantes que encuentre")
        case .freelance: return String(localized: "envía propuestas, y seguimientos a proyectos donde ya escribiste")
        case .clients: return String(localized: "manda seguimientos a empresas que ya recibieron un correo tuyo")
        case .content, .profile, .analyst: return ""
        }
    }

    public static func explanation(for kinds: [AgentKind], agents repository: AgentRepository) -> String {
        let lines = kinds.filter(Self.agents.contains).map { "• \(repository.load($0).name) \(whatItDoes($0))" }
        return String(localized: "Con el envío automático, sin esperar tu \"si\":\n") + lines.joined(separator: "\n")
            + String(
                localized: "\n\nNunca salen solos: respuestas a clientes, publicaciones, correos en frío y seguimientos a alguien nuevo. ")
            + String(localized: "El cupo diario de cada agente sigue igual y todo se verifica como siempre.")
    }

    public static func turnOn(_ kind: AgentKind, from origin: String, agents repository: AgentRepository) {
        guard Self.agents.contains(kind) else { return }
        repository.update(kind) { $0.autoApprove = true }
        Log.write("Envío automático de \(repository.load(kind).name) prendido desde \(origin)")
    }

    public static func turnOff(_ kind: AgentKind, from origin: String, agents repository: AgentRepository) {
        repository.update(kind) { $0.autoApprove = false }
        Log.write("Envío automático de \(repository.load(kind).name) apagado desde \(origin)")
    }

    public static func newlyEnabled(saved: [AgentSettings], edited: [AgentSettings]) -> [AgentKind] {
        edited.filter { agent in
            agent.autoApprove && agents.contains(agent.id) && !(saved.first { $0.id == agent.id }?.autoApprove ?? false)
        }.map(\.id)
    }
}
