import Foundation
import HirebarDomain

extension ContentAccount {
    public var folder: URL { Paths.content.appendingPathComponent(id, isDirectory: true) }
    public var slides: URL { folder.appendingPathComponent("laminas", isDirectory: true) }
    public var draft: URL { folder.appendingPathComponent("borrador.md") }
    public var videoFolder: URL { folder.appendingPathComponent("video", isDirectory: true) }
    public var changes: URL { folder.appendingPathComponent("cambios.txt") }
    public var performance: URL { folder.appendingPathComponent("rendimiento.md") }
    public var relativeFolder: String { "contenido/\(id)" }
}
