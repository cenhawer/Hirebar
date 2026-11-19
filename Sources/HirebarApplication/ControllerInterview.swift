import Foundation
import HirebarDomain

extension BatchItem {
    public init(_ entry: ActivityEntry) {
        self.init(
            id: entry.id, platform: entry.agent.rawValue, kind: entry.action.rawValue, title: entry.target.displayText,
            url: entry.target.displayText, detail: entry.text ?? "")
    }
}

extension Controller {
    func runInterviewPrep(_ query: String) {
        let matches = Self.matchingActivity(query, in: stores.executionState.activity())
        switch matches.count {
        case 0:
            reply(
                query.isEmpty
                    ? String(localized: "No tienes postulaciones enviadas todavía.")
                    : String(localized: "No encontré ninguna postulación con \"\(query)\"."))
        case 1:
            startInterviewPrep(for: matches[0])
        default:
            let lines = matches.prefix(8).map { "• \($0.target.displayText)" }.joined(separator: "\n")
            reply(String(localized: "Tienes varias postulaciones; dime cuál con más detalle:\n\(lines)"))
        }
    }

    static func matchingActivity(_ query: String, in entries: [ActivityEntry]) -> [ActivityEntry] {
        let applied = entries.filter { [.apply, .sendProposal].contains($0.action) && $0.outcome == .sent }
        let normalizedQuery = TextTools.normalize(query).trimmingCharacters(in: .whitespaces)
        var seen = Set<String>()
        let unique = applied.sorted { $0.at > $1.at }.filter { seen.insert($0.batch).inserted }
        guard !normalizedQuery.isEmpty else { return unique }
        return unique.filter { TextTools.normalize($0.target.displayText + " " + ($0.text ?? "")).contains(normalizedQuery) }
    }

    func startInterviewPrep(for entry: ActivityEntry) {
        let item = BatchItem(entry)
        let batch = Batch(mode: .interviewPrep, items: [item], status: .running, manual: true)
        if runningMode == .interviewPrep || queue.contains(where: { $0.0.mode == .interviewPrep }) {
            reply(String(localized: "Ya estoy preparando una entrevista; te mando esa primero."))
            return
        }
        stores.batches.upsert(batch)
        queue.append((batch, [item]))
        reply(String(localized: "Preparando tu entrevista para \(entry.target.displayText); te la mando al terminar."))
        if running == nil { runNext() }
    }
}
