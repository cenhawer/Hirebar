import Foundation
import HirebarDomain

extension ContentAccount {
    public var folder: URL { Paths.content.appendingPathComponent(id, isDirectory: true) }
    public var slides: URL { folder.appendingPathComponent("laminas", isDirectory: true) }
    public var draft: URL { folder.appendingPathComponent("borrador.md") }
    public var videoFolder: URL { folder.appendingPathComponent("video", isDirectory: true) }

    public var music: URL? {
        ["mp3", "m4a", "wav", "aiff"].map { folder.appendingPathComponent("musica.\($0)") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }
    public var changes: URL { folder.appendingPathComponent("cambios.txt") }
    public var performance: URL { folder.appendingPathComponent("rendimiento.md") }

    public var needsPerformanceCheck: Bool {
        guard let date = (try? FileManager.default.attributesOfItem(atPath: performance.path))?[.modificationDate] as? Date else {
            return true
        }
        return Date().timeIntervalSince(date) > 7 * 86400
    }

    public var relativeFolder: String { "contenido/\(id)" }

    public var hasDraft: Bool {
        let text = (try? String(contentsOf: draft, encoding: .utf8)) ?? ""
        return text.trimmingCharacters(in: .whitespacesAndNewlines).count > 20
    }
}

public enum ContentAccountStore {
    public static var url: URL { Paths.content.appendingPathComponent("cuentas.json") }

    public static func load() -> [ContentAccount] {
        guard let data = try? Data(contentsOf: url) else { return [defaultAccount()] }
        do {
            let accounts = try JSONDecoder().decode([ContentAccount].self, from: data)
            return accounts.isEmpty ? [defaultAccount()] : accounts
        } catch {
            Log.write("contenido/cuentas.json tiene un error (\(error.localizedDescription)); se usa la cuenta por defecto")
            return [defaultAccount()]
        }
    }

    public static func save(_ accounts: [ContentAccount]) throws {
        try FileManager.default.createDirectory(at: Paths.content, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(accounts).write(to: url, options: .atomic)
    }

    public static func defaultAccount() -> ContentAccount {
        let owner = Config.load().ownerName
        return ContentAccount(id: "personal", name: owner == "el usuario" ? "" : owner)
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
