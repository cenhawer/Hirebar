import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.storage)

public enum WorkspaceMigration {
    static let seenKeys = ["radar.seen", "jobradar.seen"]
    static let waitingVoiceKey = "video.esperandoVoz"
    static let chatOffsetKey = "telegram.offset"
    static let claimPrefix = "sched."

    public static func run(
        defaults: UserDefaults = .standard, runState: FileRunStateRepository, at date: Date = Date()
    ) {
        Paths.ensure()
        for file in versionedFiles() { upgrade(file, at: date) }
        moveDefaults(defaults, into: runState)
    }

    static func versionedFiles() -> [(url: URL, listKey: String?)] {
        let agents = (try? FileManager.default.contentsOfDirectory(at: AgentStore.folder, includingPropertiesForKeys: nil)) ?? []
        return [(Paths.config, nil), (Profile.url, nil), (ContentAccountStore.url, ContentAccountStore.listKey)]
            + agents.filter { $0.pathExtension == "json" }.map { ($0, nil) }
    }

    static func upgrade(_ file: (url: URL, listKey: String?), at date: Date) {
        guard let data = try? Data(contentsOf: file.url) else { return }
        let version = VersionedJSON.version(of: data)
        guard version < WorkspaceSchema.current else {
            if version > WorkspaceSchema.current { log.write("\(file.url.lastPathComponent) es de una versión más nueva de Hirebar") }
            return
        }
        do {
            try backUp(data, of: file.url, version: version, at: date)
            guard let upgraded = VersionedJSON.stamped(data, listKey: file.listKey) else {
                log.write("\(file.url.lastPathComponent) no es JSON válido; quedó el respaldo y no se migró")
                return
            }
            try upgraded.write(to: file.url, options: .atomic)
            log.write("\(file.url.lastPathComponent) migrado a la versión \(WorkspaceSchema.current)")
        } catch {
            log.write("No pude migrar \(file.url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    static func backUp(_ data: Data, of url: URL, version: Int, at date: Date) throws {
        try FileManager.default.createDirectory(at: Paths.backups, withIntermediateDirectories: true)
        let relative = url.path.replacingOccurrences(of: Paths.root.path + "/", with: "").replacingOccurrences(of: "/", with: "-")
        let stamp = Int(date.timeIntervalSince1970)
        let name = (relative as NSString).deletingPathExtension + ".v\(version).\(stamp).json"
        try data.write(to: Paths.backups.appendingPathComponent(name), options: .atomic)
    }

    static func moveDefaults(_ defaults: UserDefaults, into runState: FileRunStateRepository) {
        let stored = defaults.dictionaryRepresentation()
        let claims = stored.keys.filter { $0.hasPrefix(claimPrefix) && defaults.bool(forKey: $0) }
        var seen: [String: [String: Date]] = [:]
        for key in seenKeys {
            if let values = defaults.dictionary(forKey: key) as? [String: Date] { seen[key] = values }
        }
        let waiting = defaults.string(forKey: waitingVoiceKey)
        let offset = defaults.integer(forKey: chatOffsetKey)
        let legacyKeys = seenKeys + [waitingVoiceKey, chatOffsetKey] + stored.keys.filter { $0.hasPrefix(claimPrefix) }
        guard legacyKeys.contains(where: { stored[$0] != nil }) else { return }
        runState.absorb(seen: seen, claimed: claims, waitingVoiceAccount: waiting, chatOffset: offset)
        for key in legacyKeys { defaults.removeObject(forKey: key) }
        log.write("Estado de corrida movido de las preferencias del sistema al workspace")
    }
}
