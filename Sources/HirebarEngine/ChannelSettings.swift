import Foundation
import HirebarCore

struct ChannelSettings: Decodable, Equatable, Sendable {
    static let fileName = "canal"
    static let supportedSchemaVersion = 1
    static let secondsPerMinute: TimeInterval = 60

    let schemaVersion: Int
    let pairingMinutes: Int
    let messagesPerMinute: Int

    var pairingWindow: TimeInterval { TimeInterval(pairingMinutes) * Self.secondsPerMinute }

    enum LoadFailure: Error {
        case missing
        case unsupportedVersion(Int)
    }

    static func load(from url: URL) throws -> ChannelSettings {
        let settings = try JSONDecoder().decode(ChannelSettings.self, from: Data(contentsOf: url))
        guard settings.schemaVersion == supportedSchemaVersion else { throw LoadFailure.unsupportedVersion(settings.schemaVersion) }
        return settings
    }

    static func bundled(in bundle: Bundle = .main) throws -> ChannelSettings {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else { throw LoadFailure.missing }
        return try load(from: url)
    }
}
