import Foundation
import HirebarDomain

public enum Housekeeping {
    static let keepRunsDays = 30.0
    static let keepFinishedDays = 90.0
    static let keepWeeks = 26
    static let keepEventsDays = 180.0
    static let keepReportsDays = 365.0
    static let logMaxBytes = 5_000_000
    static let logKeepBytes = 1_000_000
    static let textMaxBytes = 3_000_000
    static let textKeepBytes = 1_500_000
    static let growingFiles = ["historial-propuestas.md", "postulaciones.md", "informes/cambios.md"]

    public static func run() {
        let now = Date()
        var notes: [String] = []

        let removedRuns = removeOlder(than: keepRunsDays, in: Paths.runs, now: now)
        if removedRuns > 0 { notes.append("\(removedRuns) archivos de ejecuciones") }

        do {
            try FileExecutionStateStore.standard.removeRecords(before: now.addingTimeInterval(-keepRunsDays * 86400))
        } catch {
            notes.append("no pude limpiar el estado de ejecución (\(error.localizedDescription))")
        }

        let removedReports = removeOlder(than: keepReportsDays, in: Paths.reports, now: now, except: ["cambios.md"])
        if removedReports > 0 { notes.append("\(removedReports) informes de hace más de un año") }

        let followUps = Paths.workspaceFile("seguimiento.json")
        if var root = readJSON(followUps) as? [String: Any], let list = root["propuestas"] as? [[String: Any]] {
            let kept = list.filter { item in
                let state = item["estado"] as? String ?? "activa"
                if ["activa", "conversacion", "ganada"].contains(state) { return true }
                guard let sent = (item["enviada"] as? String).flatMap(parseISO) else { return true }
                return now.timeIntervalSince(sent) < keepFinishedDays * 86400
            }
            if kept.count < list.count {
                root["propuestas"] = kept
                writeJSON(root, followUps)
                notes.append("\(list.count - kept.count) propuestas terminadas del seguimiento")
            }
        }

        if var root = readJSON(Metrics.url) as? [String: Any] {
            var changed = false
            if let weeks = root["semanas"] as? [String: Any], weeks.count > keepWeeks {
                let keep = Set(weeks.keys.sorted().suffix(keepWeeks))
                root["semanas"] = weeks.filter { keep.contains($0.key) }
                changed = true
            }
            if let events = root["eventos"] as? [[String: Any]] {
                let kept = events.filter { event in
                    guard let date = (event["fecha"] as? String).flatMap(parseISO) else { return true }
                    return now.timeIntervalSince(date) < keepEventsDays * 86400
                }
                if kept.count < events.count {
                    root["eventos"] = kept
                    changed = true
                }
            }
            if changed {
                writeJSON(root, Metrics.url)
                notes.append("métricas de la app")
            }
        }
        if let root = readJSON(Metrics.agentURL) as? [String: Any], root.count > keepWeeks {
            let keep = Set(root.keys.sorted().suffix(keepWeeks))
            writeJSON(root.filter { keep.contains($0.key) }, Metrics.agentURL)
            notes.append("métricas de Claude")
        }

        if trim(Paths.log, max: logMaxBytes, keep: logKeepBytes, newestAtTop: false) { notes.append("registro") }
        for name in growingFiles where trim(Paths.workspaceFile(name), max: textMaxBytes, keep: textKeepBytes, newestAtTop: true) {
            notes.append(name)
        }

        Log.write("Limpieza semanal: " + (notes.isEmpty ? "nada que borrar" : notes.joined(separator: ", ")))
    }

    private static func removeOlder(than days: Double, in folder: URL, now: Date, except: Set<String> = []) -> Int {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) else { return 0 }
        var removed = 0
        for file in files where !except.contains(file.lastPathComponent) {
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? now
            if now.timeIntervalSince(date) > days * 86400 {
                try? fm.removeItem(at: file)
                removed += 1
            }
        }
        return removed
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
            kept += "\n\n(Lo más antiguo se borró en la limpieza automática.)\n"
        } else {
            kept = String(decoding: data.suffix(keep), as: UTF8.self)
            if let cut = kept.firstIndex(of: "\n") { kept = String(kept[kept.index(after: cut)...]) }
        }
        try? kept.write(to: url, atomically: true, encoding: .utf8)
        return true
    }
}
