import Foundation
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

enum CommandVocabularyFile {
    static let fileName = "comandos"
    static let supportedSchemaVersion = 1

    enum LoadFailure: Error {
        case missing
        case unsupportedVersion(Int)
        case repeatedVerbs([String])
    }

    static func load(from url: URL) throws -> CommandVocabulary {
        let vocabulary = try JSONDecoder().decode(CommandVocabulary.self, from: Data(contentsOf: url))
        guard vocabulary.schemaVersion == supportedSchemaVersion else { throw LoadFailure.unsupportedVersion(vocabulary.schemaVersion) }
        guard vocabulary.repeatedVerbs.isEmpty else { throw LoadFailure.repeatedVerbs(vocabulary.repeatedVerbs) }
        return vocabulary
    }

    static func bundled(in bundle: Bundle = .main) throws -> CommandVocabulary {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else { throw LoadFailure.missing }
        return try load(from: url)
    }
}
