import Foundation
import HirebarDomain

public struct SystemTools: Decodable, Equatable, Sendable {
    public struct Tool: Decodable, Equatable, Sendable {
        public let paths: [String]
        public let install: String
    }

    public static let fileName = "herramientas"
    public static let supportedSchemaVersion = 1
    public static let bytesPerMegabyte = 1_048_576

    public let schemaVersion: Int
    public let ffmpeg: Tool
    public let maxAudioMegabytes: Int
    public let maxAudioSeconds: Int

    public var maxAudioBytes: Int { maxAudioMegabytes * Self.bytesPerMegabyte }

    public enum LoadFailure: Error {
        case missing
        case unsupportedVersion(Int)
    }

    public static func load(from url: URL) throws -> SystemTools {
        let tools = try JSONDecoder().decode(SystemTools.self, from: Data(contentsOf: url))
        guard tools.schemaVersion == supportedSchemaVersion else { throw LoadFailure.unsupportedVersion(tools.schemaVersion) }
        return tools
    }

    public static func bundled(in bundle: Bundle = .main) throws -> SystemTools {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else { throw LoadFailure.missing }
        return try load(from: url)
    }

    public func ffmpegPath(isExecutable: (String) -> Bool = FileManager.default.isExecutableFile(atPath:)) -> String? {
        ffmpeg.paths.first(where: isExecutable)
    }

    public func acceptsAudio(bytes: Int?, seconds: Int?) -> Bool {
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
