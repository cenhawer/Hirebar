import Foundation
import HirebarApplication
import HirebarDomain

public enum BatchStore {
    public static var url: URL { Paths.workspaceFile("lotes.json") }

    private struct Lossy: Decodable {
        let batch: Batch?
        init(from decoder: Decoder) throws { batch = try? Batch(from: decoder) }
    }

    public static func load() -> [Batch] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return ((try? decoder.decode([Lossy].self, from: data)) ?? []).compactMap(\.batch)
    }

    public static func save(_ batches: [Batch], keeping window: TimeInterval) {
        Paths.ensure()
        let cutoff = Date().addingTimeInterval(-window)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(batches.filter { $0.created > cutoff }) {
            try? data.write(to: url, options: .atomic)
        }
    }

    public static func upsert(_ batch: Batch, keeping window: TimeInterval) {
        var all = load()
        if let index = all.firstIndex(where: { $0.id == batch.id }) { all[index] = batch } else { all.append(batch) }
        save(all, keeping: window)
    }

    public static func find(id: String) -> Batch? { load().first { $0.id == id } }
    public static func find(messageId: Int) -> Batch? { load().first { $0.messageId == messageId } }

    public static func latestPending() -> Batch? {
        let since = Date().addingTimeInterval(-24 * 3600)
        return load().filter { $0.status == .pending && $0.created > since }.max { $0.created < $1.created }
    }
}
