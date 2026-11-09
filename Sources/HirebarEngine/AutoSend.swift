import Foundation
import HirebarCore
import HirebarDomain

public enum AutoSend {
    public static let agents: [AgentKind] = [.jobs, .freelance, .clients]

    static func whatItDoes(_ kind: AgentKind) -> String {
        switch kind {
        case .jobs: return "postula a las vacantes que encuentre"
        case .freelance: return "envía propuestas, y seguimientos a proyectos donde ya escribiste"
        case .clients: return "manda seguimientos a empresas que ya recibieron un correo tuyo"
        case .content, .profile, .analyst: return ""
        }
    }

    public static func explanation(for kinds: [AgentKind]) -> String {
        let lines = kinds.filter(agents.contains).map { "• \(AgentStore.load($0).name) \(whatItDoes($0))" }
        return "Con el envío automático, sin esperar tu \"si\":\n" + lines.joined(separator: "\n")
            + "\n\nNunca salen solos: respuestas a clientes, publicaciones, correos en frío y seguimientos a alguien nuevo. "
            + "El cupo diario de cada agente sigue igual y todo se verifica como siempre."
    }

    public static func turnOn(_ kind: AgentKind, from origin: String) {
        guard agents.contains(kind) else { return }
        AgentStore.update(kind) { $0.autoApprove = true }
        Log.write("Envío automático de \(AgentStore.load(kind).name) prendido desde \(origin)")
    }

    public static func turnOff(_ kind: AgentKind, from origin: String) {
        AgentStore.update(kind) { $0.autoApprove = false }
        Log.write("Envío automático de \(AgentStore.load(kind).name) apagado desde \(origin)")
    }

    public static func newlyEnabled(saved: [AgentSettings], edited: [AgentSettings]) -> [AgentKind] {
        edited.filter { agent in
            agent.autoApprove && agents.contains(agent.id) && !(saved.first { $0.id == agent.id }?.autoApprove ?? false)
        }.map(\.id)
    }
}
