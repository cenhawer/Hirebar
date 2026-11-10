import Foundation
import HirebarDomain

public struct ChannelSettings: Decodable, Equatable, Sendable {
    public static let fileName = "canal"
    static let supportedSchemaVersion = 1
    static let secondsPerMinute: TimeInterval = 60

    public let schemaVersion: Int
    public let pairingMinutes: Int
    public let messagesPerMinute: Int

    public var pairingWindow: TimeInterval { TimeInterval(pairingMinutes) * Self.secondsPerMinute }

    public static func decode(_ data: Data) throws -> ChannelSettings {
        let settings = try JSONDecoder().decode(ChannelSettings.self, from: data)
        guard settings.schemaVersion == supportedSchemaVersion else {
            throw ResourceFailure.unsupportedVersion(settings.schemaVersion)
        }
        guard settings.pairingMinutes > 0, settings.messagesPerMinute > 0 else { throw ResourceFailure.invalidValues }
        return settings
    }
}

public enum ResourceFailure: Error, Equatable {
    case missing
    case unsupportedVersion(Int)
    case invalidValues
    case repeatedVerbs([String])
}

public enum CommandVocabularyFile {
    public static let fileName = "comandos"
    static let supportedSchemaVersion = 1

    public static func decode(_ data: Data) throws -> CommandVocabulary {
        let vocabulary = try JSONDecoder().decode(CommandVocabulary.self, from: data)
        guard vocabulary.schemaVersion == supportedSchemaVersion else {
            throw ResourceFailure.unsupportedVersion(vocabulary.schemaVersion)
        }
        guard vocabulary.repeatedVerbs.isEmpty else { throw ResourceFailure.repeatedVerbs(vocabulary.repeatedVerbs) }
        return vocabulary
    }
}

public struct TargetRulesFile: Decodable, Sendable {
    public static let fileName = "destinos"
    static let supportedSchemaVersion = 1

    let schemaVersion: Int
    let webSchemes: [String]
    let ignoredQueryParameters: [String]
    let ignoredQueryParameterPrefixes: [String]

    var rules: TargetRules {
        TargetRules(
            ignoredQueryParameters: Set(ignoredQueryParameters),
            ignoredQueryParameterPrefixes: ignoredQueryParameterPrefixes,
            networks: Set(ContentNetwork.allCases.map(\.rawValue)),
            webSchemes: Set(webSchemes)
        )
    }

    public static var fallback: TargetRules {
        TargetRules(
            ignoredQueryParameters: [], ignoredQueryParameterPrefixes: [], networks: Set(ContentNetwork.allCases.map(\.rawValue)),
            webSchemes: TargetRules.strict.webSchemes)
    }

    public static func decode(_ data: Data) throws -> TargetRules {
        let file = try JSONDecoder().decode(TargetRulesFile.self, from: data)
        guard file.schemaVersion == supportedSchemaVersion else { throw ResourceFailure.unsupportedVersion(file.schemaVersion) }
        return file.rules
    }
}

public struct EngineResources: Sendable {
    public let targetRules: TargetRules
    public let commands: CommandVocabulary?
    public let channel: ChannelSettings?
    public let policy: EnginePolicy
    public let searchDefaults: SearchProfile
    public let retention: RetentionPolicy

    public init(
        targetRules: TargetRules, commands: CommandVocabulary?, channel: ChannelSettings?, policy: EnginePolicy,
        searchDefaults: SearchProfile, retention: RetentionPolicy
    ) {
        self.searchDefaults = searchDefaults
        self.retention = retention
        self.targetRules = targetRules
        self.commands = commands
        self.channel = channel
        self.policy = policy
    }
}
