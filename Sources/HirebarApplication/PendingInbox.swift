import Foundation
import HirebarDomain

public struct InboxItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let number: Int
    public let title: String
    public let kind: String
    public let platform: String
    public let target: String
    public let detail: String
}

public struct InboxList: Identifiable, Equatable, Sendable {
    public let id: String
    public let mode: Mode
    public let title: String
    public let created: Date
    public let items: [InboxItem]
}

public struct InboxDraft: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let text: String
    public let slides: [URL]
    public let video: URL?
}

public enum PendingInbox {
    public static func lists(from batches: [Batch]) -> [InboxList] {
        batches.filter { $0.status == .pending && !$0.items.isEmpty }
            .sorted { $0.created > $1.created }
            .map { batch in
                let items = batch.items.enumerated().map { index, item in
                    InboxItem(
                        id: "\(batch.id)#\(index + 1)", number: index + 1, title: item.title, kind: item.kind, platform: item.platform,
                        target: item.url, detail: item.detail)
                }
                return InboxList(id: batch.id, mode: batch.mode, title: batch.mode.title, created: batch.created, items: items)
            }
    }
}

public struct InboxSelection: Equatable, Sendable {
    private var chosen: [String: Set<Int>] = [:]

    public init() {}

    public func isSelected(_ number: Int, in list: String) -> Bool {
        chosen[list]?.contains(number) ?? false
    }

    public mutating func toggle(_ number: Int, in list: String) {
        var numbers = chosen[list] ?? []
        if numbers.contains(number) { numbers.remove(number) } else { numbers.insert(number) }
        chosen[list] = numbers.isEmpty ? nil : numbers
    }

    public func count(in list: String) -> Int {
        chosen[list]?.count ?? 0
    }

    public func picks(for list: InboxList) -> [Int]? {
        let numbers = (chosen[list.id] ?? []).filter { (1...list.items.count).contains($0) }
        guard !numbers.isEmpty else { return nil }
        return numbers.count == list.items.count ? [] : numbers.sorted()
    }

    public mutating func clear(_ list: String) {
        chosen[list] = nil
    }
}
