import Foundation
import HirebarDomain

public enum WeeklyStats {
    static let fields: [AgentKind: (section: String, items: [([String], String)])] = [
        .jobs: ("empleo", [(["enviadas"], "postuladas"), (["vistas"], "vistas"), (["respuestas"], "respuestas"), (["entrevistas"], "entrevistas")]),
        .freelance: ("freelance", [(["enviadas"], "enviadas"), (["leidas"], "leídas"), (["respuestas"], "respuestas"), (["ganados"], "ganados")]),
        .clients: ("prospeccion", [(["enviados_empresas", "enviados_negocios"], "correos"), (["seguimientos"], "seguimientos"), (["respuestas"], "respuestas"), (["rebotes"], "rebotes")]),
    ]

    public static func lines(for kind: AgentKind, week: String = Metrics.weekKey(), source: URL = Metrics.agentURL) -> [String] {
        guard let spec = fields[kind] else { return [] }
        let root = (try? Data(contentsOf: source)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        let section = (root[week] as? [String: Any])?[spec.section] as? [String: Any] ?? [:]
        func value(_ keys: [String]) -> Int { keys.reduce(0) { $0 + ((section[$1] as? NSNumber)?.intValue ?? 0) } }
        return spec.items.enumerated().compactMap { index, item in
            let amount = value(item.0)
            return index == 0 || amount > 0 ? "\(amount) \(item.1)" : nil
        }
    }
}
