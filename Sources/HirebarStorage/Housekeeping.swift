import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.storage)

public enum Housekeeping {
    static let growingFiles = ["historial-propuestas.md", "postulaciones.md", "informes/cambios.md"]

    public static func run(policy: RetentionPolicy, at now: Date = Date()) {
        var notes = removeRuns(policy: policy, now: now)
        notes += cleanFollowUps(policy: policy, now: now)
        notes += cleanMetrics(policy: policy, now: now)
        for name in growingFiles
        where trim(Paths.workspaceFile(name), max: policy.historialMaximoBytes, keep: policy.historialConservaBytes, newestAtTop: true) {
            notes.append(name)
        }
        notes += removeMedia(policy: policy, now: now)
        log.write("Limpieza semanal: " + (notes.isEmpty ? "nada que borrar" : notes.joined(separator: ", ")))
    }

    static func removeRuns(policy: RetentionPolicy, now: Date) -> [String] {
        var notes: [String] = []
        let removedRuns = removeOlder(than: policy.runs, in: Paths.runs, now: now)
        if removedRuns > 0 { notes.append(String(localized: "\(removedRuns) archivos de ejecuciones")) }
        do {
            try FileExecutionStateStore.standard.removeRecords(before: now.addingTimeInterval(-policy.runs))
        } catch {
            notes.append(String(localized: "no pude limpiar el estado de ejecución (\(error.localizedDescription))"))
        }
        let removedReports = removeOlder(than: policy.reports, in: Paths.reports, now: now) { $0 != "cambios.md" }
        if removedReports > 0 { notes.append(String(localized: "\(removedReports) informes de hace más de un año")) }
        return notes
    }

    static func cleanFollowUps(policy: RetentionPolicy, now: Date) -> [String] {
        let followUps = Paths.workspaceFile("seguimiento.json")
        guard var root = readJSON(followUps) as? [String: Any], let list = root["propuestas"] as? [[String: Any]] else { return [] }
        let kept = list.filter { item in
            let state = item["estado"] as? String ?? "activa"
            if ["activa", "conversacion", "ganada"].contains(state) { return true }
            guard let sent = (item["enviada"] as? String).flatMap(parseISO) else { return true }
            return now.timeIntervalSince(sent) < policy.finishedFollowUps
        }
        guard kept.count < list.count else { return [] }
        root["propuestas"] = kept
        writeJSON(root, followUps)
        return [String(localized: "\(list.count - kept.count) propuestas terminadas del seguimiento")]
    }

    static func cleanMetrics(policy: RetentionPolicy, now: Date) -> [String] {
        var notes: [String] = []
        if var root = readJSON(Metrics.url) as? [String: Any] {
            var changed = false
            if let weeks = root["semanas"] as? [String: Any], weeks.count > policy.metricasSemanas {
                let keep = Set(weeks.keys.sorted().suffix(policy.metricasSemanas))
                root["semanas"] = weeks.filter { keep.contains($0.key) }
                changed = true
            }
            if let events = root["eventos"] as? [[String: Any]] {
                let kept = events.filter { event in
                    guard let date = (event["fecha"] as? String).flatMap(parseISO) else { return true }
                    return now.timeIntervalSince(date) < policy.events
                }
                if kept.count < events.count {
                    root["eventos"] = kept
                    changed = true
                }
            }
            if changed {
                writeJSON(root, Metrics.url)
                notes.append(String(localized: "métricas de la app"))
            }
        }
        if let root = readJSON(Metrics.agentURL) as? [String: Any], root.count > policy.metricasSemanas {
            let keep = Set(root.keys.sorted().suffix(policy.metricasSemanas))
            writeJSON(root.filter { keep.contains($0.key) }, Metrics.agentURL)
            notes.append(String(localized: "métricas de Claude"))
        }
        return notes
    }

    static func parseISO(_ text: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: text) { return date }
        return Quotas.day(text)
    }

    private static func readJSON(_ url: URL) -> Any? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func writeJSON(_ object: Any, _ url: URL) {
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url, options: .atomic)
        }
    }

    @discardableResult
    static func trim(_ url: URL, max: Int, keep: Int, newestAtTop: Bool) -> Bool {
        guard let data = try? Data(contentsOf: url), data.count > max else { return false }
        var kept: String
        if newestAtTop {
            kept = String(decoding: data.prefix(keep), as: UTF8.self)
            if let cut = kept.lastIndex(of: "\n") { kept = String(kept[..<cut]) }
            kept += String(localized: "\n\n(Lo más antiguo se borró en la limpieza automática.)\n")
        } else {
            kept = String(decoding: data.suffix(keep), as: UTF8.self)
            if let cut = kept.firstIndex(of: "\n") { kept = String(kept[kept.index(after: cut)...]) }
        }
        try? kept.write(to: url, atomically: true, encoding: .utf8)
        return true
    }
}
