import Foundation
import HirebarApplication
import HirebarDomain

public struct EngineProfiles: Decodable, Sendable {
    public struct ClaudePhase: Decodable, Sendable {
        let permissionMode: String
        let restricted: Bool
        let tools: [String]
        let browserTools: [String]
        let denyPersonalFiles: Bool
    }

    public struct Claude: Decodable, Sendable {
        let personalFiles: [String]
        let read: ClaudePhase
        let draft: ClaudePhase
        let act: ClaudePhase

        public func phase(_ profile: RunProfile) -> ClaudePhase {
            switch profile {
            case .read: return read
            case .draft: return draft
            case .act: return act
            }
        }
    }

    public struct CommandEngine: Decodable, Sendable {
        let read: String
        let draft: String
        let act: String
        let browserInRead: Bool

        public func command(_ profile: RunProfile) -> String {
            switch profile {
            case .read: return read
            case .draft: return draft
            case .act: return act
            }
        }
    }

    public static let fileName = "perfiles-ia"
    public static let supportedSchemaVersion = 1

    public let schemaVersion: Int
    public let protectedFiles: [String]
    public let restoredFiles: [String]
    public let claude: Claude
    public let codex: CommandEngine
    public let gemini: CommandEngine

    public enum LoadFailure: Error {
        case missing
        case unsupportedVersion(Int)
    }

    public static func load(from url: URL) throws -> EngineProfiles {
        let profiles = try JSONDecoder().decode(EngineProfiles.self, from: Data(contentsOf: url))
        guard profiles.schemaVersion == supportedSchemaVersion else { throw LoadFailure.unsupportedVersion(profiles.schemaVersion) }
        return profiles
    }

    public static func bundled(in bundle: Bundle = .main) throws -> EngineProfiles {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else { throw LoadFailure.missing }
        return try load(from: url)
    }
}

public enum EngineCommands {
    public struct Phases: Sendable {
        public let read: String
        public let act: String
    }

    public static func phases(for kind: AIEngineKind) -> Phases? {
        guard let profiles = try? EngineProfiles.bundled() else { return nil }
        switch kind {
        case .codex: return Phases(read: profiles.codex.read, act: profiles.codex.act)
        case .gemini: return Phases(read: profiles.gemini.read, act: profiles.gemini.act)
        case .claude, .custom: return nil
        }
    }
}
