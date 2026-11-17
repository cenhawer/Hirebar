import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.storage)

extension AgentKind {
    public static func parse(_ text: String) -> AgentKind? {
        alias(text) ?? named(text)
    }

    static func named(_ text: String) -> AgentKind? {
        let wanted = TextTools.normalize(text).trimmingCharacters(in: .whitespaces)
        guard !wanted.isEmpty else { return nil }
        return allCases.first { TextTools.normalize(AgentStore.load($0).name).trimmingCharacters(in: .whitespaces) == wanted }
    }
}

extension Config {
    public var agentDefaults: AgentDefaults {
        var defaults = AgentDefaults()
        defaults.jobsOn = jobsOn
        defaults.freelanceOn = freelanceOn
        defaults.autoJobs = autoJobs
        defaults.autoFreelance = autoFreelance
        defaults.autoEmails = autoEmails
        defaults.jobMinutes = jobMinutes
        defaults.freelanceMinutes = freelanceMinutes
        return defaults
    }
}

public enum AgentStore {
    public static var folder: URL { Paths.workspace.appendingPathComponent("agentes", isDirectory: true) }

    public static func url(for kind: AgentKind) -> URL {
        folder.appendingPathComponent("\(kind.rawValue).json")
    }

    public static func load(_ kind: AgentKind) -> AgentSettings {
        guard let data = try? Data(contentsOf: url(for: kind)) else {
            return AgentSettings.defaults(for: kind, legacy: Config.load().agentDefaults)
        }
        do {
            var settings = try JSONDecoder().decode(AgentSettings.self, from: data)
            if kind == .content {
                settings.tasks = settings.tasks.map { task in
                    var task = task
                    if task.mode == .linkedInDraft { task.days = ["todos"] }
                    return task
                }
            }
            return settings
        } catch {
            log.write("agentes/\(kind.rawValue).json tiene un error (\(error.localizedDescription)); se usa la configuración por defecto")
            return AgentSettings.defaults(for: kind, legacy: Config.load().agentDefaults)
        }
    }

    public static func all() -> [AgentSettings] { AgentKind.allCases.map(load) }

    public static func save(_ settings: AgentSettings) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? VersionedJSON.write(settings, to: url(for: settings.id))
    }

    public static func update(_ kind: AgentKind, _ change: (inout AgentSettings) -> Void) {
        var settings = load(kind)
        change(&settings)
        save(settings)
    }

    public static func writeMissingDefaults() {
        let config = Config.load().agentDefaults
        for kind in AgentKind.allCases where !FileManager.default.fileExists(atPath: url(for: kind).path) {
            save(AgentSettings.defaults(for: kind, legacy: config))
        }
    }
}
