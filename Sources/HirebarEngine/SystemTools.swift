import Foundation
import HirebarCore

struct SystemTools: Decodable, Equatable, Sendable {
    struct Tool: Decodable, Equatable, Sendable {
        let paths: [String]
        let install: String
    }

    static let fileName = "herramientas"
    static let supportedSchemaVersion = 1
    static let bytesPerMegabyte = 1_048_576

    let schemaVersion: Int
    let ffmpeg: Tool
    let maxAudioMegabytes: Int
    let maxAudioSeconds: Int

    var maxAudioBytes: Int { maxAudioMegabytes * Self.bytesPerMegabyte }

    enum LoadFailure: Error {
        case missing
        case unsupportedVersion(Int)
    }

    static func load(from url: URL) throws -> SystemTools {
        let tools = try JSONDecoder().decode(SystemTools.self, from: Data(contentsOf: url))
        guard tools.schemaVersion == supportedSchemaVersion else { throw LoadFailure.unsupportedVersion(tools.schemaVersion) }
        return tools
    }

    static func bundled(in bundle: Bundle = .main) throws -> SystemTools {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else { throw LoadFailure.missing }
        return try load(from: url)
    }

    func ffmpegPath(isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)) -> String? {
        ffmpeg.paths.first(where: isExecutable)
    }

    func acceptsAudio(bytes: Int?, seconds: Int?) -> Bool {
        (bytes ?? 0) <= maxAudioBytes && (seconds ?? 0) <= maxAudioSeconds
    }
}

public enum ToolCheck {
    public struct Status: Equatable, Sendable {
        public let ffmpegFound: Bool
        public let installCommand: String
    }

    public static func status() -> Status? {
        guard let tools = try? SystemTools.bundled() else { return nil }
        return Status(ffmpegFound: tools.ffmpegPath() != nil, installCommand: tools.ffmpeg.install)
    }
}
