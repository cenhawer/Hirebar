import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.ai)

enum BundledResource {
    static func data(_ name: String, in bundle: Bundle) throws -> Data {
        guard let url = bundle.url(forResource: name, withExtension: "json") else { throw ResourceFailure.missing }
        return try Data(contentsOf: url)
    }
}

extension ChannelSettings {
    public static func load(from url: URL) throws -> ChannelSettings { try decode(Data(contentsOf: url)) }
    public static func bundled(in bundle: Bundle = .main) throws -> ChannelSettings {
        try decode(BundledResource.data(fileName, in: bundle))
    }
}

extension CommandVocabularyFile {
    public static func load(from url: URL) throws -> CommandVocabulary { try decode(Data(contentsOf: url)) }
    public static func bundled(in bundle: Bundle = .main) throws -> CommandVocabulary {
        try decode(BundledResource.data(fileName, in: bundle))
    }
}

extension TargetRulesFile {
    public static func load(from url: URL) throws -> TargetRules { try decode(Data(contentsOf: url)) }
    public static func bundled(in bundle: Bundle = .main) -> TargetRules {
        guard let rules = try? decode(BundledResource.data(fileName, in: bundle)) else {
            log.write("Destinos: no encontré \(fileName).json en la app; comparo los enlaces completos")
            return fallback
        }
        return rules
    }
}

extension EnginePolicy {
    public static func load(from url: URL) throws -> EnginePolicy { try decode(Data(contentsOf: url)) }
    public static func bundled(in bundle: Bundle = .main) throws -> EnginePolicy {
        try decode(BundledResource.data(fileName, in: bundle))
    }
}

extension EngineResources {
    public static func bundled(in bundle: Bundle = .main) throws -> EngineResources {
        EngineResources(
            targetRules: TargetRulesFile.bundled(in: bundle), commands: try? CommandVocabularyFile.bundled(in: bundle),
            channel: try? ChannelSettings.bundled(in: bundle), policy: try EnginePolicy.bundled(in: bundle),
            searchDefaults: try SearchProfile.bundledDefaults(in: bundle))
    }
}
