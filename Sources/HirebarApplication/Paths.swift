import Foundation
import HirebarDomain

public enum Paths {
    public static var home: URL { URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true) }

    public static var root: URL {
        if let custom = ProcessInfo.processInfo.environment["HIREBAR_HOME"], !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
        }
        return home.appendingPathComponent("Library/Application Support/Hirebar", isDirectory: true)
    }

    public static var config: URL { root.appendingPathComponent("config.json") }
    public static var searchProfile: URL { workspace.appendingPathComponent("search-profile.json") }
    public static var workspace: URL { root.appendingPathComponent("workspace", isDirectory: true) }
    public static var runs: URL { workspace.appendingPathComponent("ejecuciones", isDirectory: true) }
    public static var reports: URL { workspace.appendingPathComponent("informes", isDirectory: true) }
    public static var prospecting: URL { workspace.appendingPathComponent("prospeccion", isDirectory: true) }
    public static var linkedIn: URL { workspace.appendingPathComponent("linkedin", isDirectory: true) }
    public static var state: URL { root.appendingPathComponent("estado", isDirectory: true) }
    public static var backups: URL { root.appendingPathComponent("respaldos", isDirectory: true) }
    public static var logs: URL { home.appendingPathComponent("Library/Logs/Hirebar", isDirectory: true) }
    public static var log: URL { logs.appendingPathComponent("hirebar.log") }

    public static func workspaceFile(_ name: String) -> URL {
        workspace.appendingPathComponent(name)
    }

    public static func playbook(for mode: Mode) -> URL {
        switch mode {
        case .linkedInDraft: return workspace.appendingPathComponent("instrucciones-contenido.md")
        case .linkedInPublish: return workspace.appendingPathComponent("instrucciones-contenido-publicar.md")
        default: return workspace.appendingPathComponent("instrucciones-\(mode.rawValue).md")
        }
    }

    public static var content: URL { workspace.appendingPathComponent("contenido", isDirectory: true) }
}
