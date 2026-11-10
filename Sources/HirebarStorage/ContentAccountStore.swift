import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.storage)

extension ContentAccount {


    public var needsPerformanceCheck: Bool {
        guard let date = (try? FileManager.default.attributesOfItem(atPath: performance.path))?[.modificationDate] as? Date else {
            return true
        }
        return Date().timeIntervalSince(date) > 7 * 86400
    }

    public var hasDraft: Bool {
        let text = (try? String(contentsOf: draft, encoding: .utf8)) ?? ""
        return text.trimmingCharacters(in: .whitespacesAndNewlines).count > 20
    }
}

public enum ContentAccountStore {
    public static var url: URL { Paths.content.appendingPathComponent("cuentas.json") }
    static let listKey = "cuentas"

    public static func load() -> [ContentAccount] {
        guard let stored = try? Data(contentsOf: url) else { return [defaultAccount()] }
        do {
            let data = VersionedJSON.list(from: stored, key: listKey) ?? stored
            let accounts = try JSONDecoder().decode([ContentAccount].self, from: data)
            return accounts.isEmpty ? [defaultAccount()] : accounts
        } catch {
            log.write("contenido/cuentas.json tiene un error (\(error.localizedDescription)); se usa la cuenta por defecto")
            return [defaultAccount()]
        }
    }

    public static func save(_ accounts: [ContentAccount]) throws {
        try FileManager.default.createDirectory(at: Paths.content, withIntermediateDirectories: true)
        try VersionedJSON.write(accounts, to: url, listKey: listKey)
    }

    public static func defaultAccount() -> ContentAccount {
        let owner = Config.load().ownerName
        return ContentAccount(id: ContentAccount.defaultIdentifier, name: owner == "el usuario" ? "" : owner)
    }

    public static func enabled() -> [ContentAccount] { load().filter(\.enabled) }

    public static func find(_ id: String?) -> ContentAccount? {
        guard let id else { return nil }
        return load().first { $0.id == id }
    }

    public static func match(_ word: String) -> ContentAccount? {
        let key = slug(word)
        guard !key.isEmpty else { return nil }
        return load().first { $0.id == key || slug($0.name.split(separator: " ").first.map(String.init) ?? "") == key }
    }

    public static func slug(_ text: String) -> String {
        let folded = text.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
        let parts = folded.split { !$0.isLetter && !$0.isNumber }
        return parts.joined(separator: "-")
    }
}
