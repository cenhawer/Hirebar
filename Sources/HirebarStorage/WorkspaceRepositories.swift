import Foundation
import HirebarApplication
import HirebarDomain

public struct FileProspectingRepository: ProspectingRepository {
    let folder: URL

    public init(folder: URL = Paths.prospecting) {
        self.folder = folder
    }

    var pending: URL { folder.appendingPathComponent("pendientes.json") }

    public func pendingEmails() -> Data? {
        try? Data(contentsOf: pending)
    }

    public func discardPendingEmails(at date: Date) {
        let stamp = Int(date.timeIntervalSince1970)
        try? FileManager.default.moveItem(at: pending, to: folder.appendingPathComponent("descartados-\(stamp).json"))
    }
}

public struct DefaultsRunStateRepository: RunStateRepository, @unchecked Sendable {
    static let waitingVoiceKey = "video.esperandoVoz"
    let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func seen(_ key: String) -> [String: Date] {
        defaults.dictionary(forKey: key) as? [String: Date] ?? [:]
    }

    public func saveSeen(_ seen: [String: Date], key: String) {
        defaults.set(seen, forKey: key)
    }

    public func claim(_ key: String) -> Bool {
        guard !defaults.bool(forKey: key) else { return false }
        defaults.set(true, forKey: key)
        return true
    }

    public func waitingVoiceAccount() -> String? {
        defaults.string(forKey: Self.waitingVoiceKey)
    }

    public func setWaitingVoiceAccount(_ id: String) {
        defaults.set(id, forKey: Self.waitingVoiceKey)
    }
}

enum ContentAccountFiles {
    static let minimumCopyableLength = 10
    static let maximumCopyableLength = 3800

    static func takeChangeRequest(_ account: ContentAccount) -> String {
        let note = (try? String(contentsOf: account.changes, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        try? FileManager.default.removeItem(at: account.changes)
        return note
    }

    static func requestChange(_ account: ContentAccount, _ note: String) {
        try? note.write(to: account.changes, atomically: true, encoding: .utf8)
    }

    static func discardDraft(_ account: ContentAccount, at date: Date) {
        let day = ISO8601DateFormatter().string(from: date).prefix(10)
        let name = "descartado-\(day)-\(Int(date.timeIntervalSince1970)).md"
        try? FileManager.default.moveItem(at: account.draft, to: account.folder.appendingPathComponent(name))
    }

    static func copyableText(_ file: URL) -> String? {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.count > minimumCopyableLength ? String(clean.prefix(maximumCopyableLength)) : nil
    }

    static func hasVideoScript(_ account: ContentAccount) -> Bool {
        FileManager.default.fileExists(atPath: account.videoScript.path)
    }

    static func latestRecording(_ account: ContentAccount) -> URL? {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: account.videoFolder, includingPropertiesForKeys: keys)) ?? []
        let modified = { (file: URL) in
            (try? file.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
        }
        return files.filter { $0.lastPathComponent.hasPrefix("grabacion.") }.max { modified($0) < modified($1) }
    }
}
