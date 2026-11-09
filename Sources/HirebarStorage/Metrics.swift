import Foundation
import HirebarApplication
import HirebarDomain

public enum Metrics {
    public static var url: URL { Paths.workspaceFile("metricas-radar.json") }
    public static var agentURL: URL { Paths.workspaceFile("metricas-claude.json") }

    public static func weekKey(_ date: Date = Date()) -> String {
        WeekKey.of(date)
    }

    public static func load() -> [String: Any] {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ["semanas": [String: Any](), "eventos": [[String: Any]]()]
        }
        return object
    }

    public static func save(_ object: [String: Any]) {
        Paths.ensure()
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url, options: .atomic)
        }
    }

    public static func bump(_ mode: Mode, _ key: String, _ amount: Int = 1) {
        guard amount > 0, mode == .freelance || mode == .jobs else { return }
        var root = load()
        var weeks = root["semanas"] as? [String: Any] ?? [:]
        let week = weekKey()
        var thisWeek = weeks[week] as? [String: Any] ?? [:]
        var section = thisWeek[mode.rawValue] as? [String: Any] ?? [:]
        section[key] = ((section[key] as? NSNumber)?.intValue ?? 0) + amount
        thisWeek[mode.rawValue] = section
        weeks[week] = thisWeek
        root["semanas"] = weeks
        save(root)
    }

    public static func event(_ text: String) {
        var root = load()
        var events = root["eventos"] as? [[String: Any]] ?? []
        events.append(["fecha": ISO8601DateFormatter().string(from: Date()), "semana": weekKey(), "texto": text])
        root["eventos"] = events
        save(root)
    }
}
