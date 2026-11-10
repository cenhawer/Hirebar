import Foundation
import HirebarDomain

public struct Config: Codable, Sendable {
    public static let freelanceSources = ["workana", "freelancer"]
    public static let jobSources = ["linkedin", "getonboard", "computrabajo", "elempleo", "magneto"]

    public static var placeholderOwnerName: String { String(localized: "el usuario") }

    public var ownerName = Config.placeholderOwnerName
    public var sources: [String: Bool] = [:]
    public var channelOwner: ChannelOwner?
    public var botUsername = ""
    public var autoFreelance = false
    public var autoJobs = false
    public var autoEmails = false
    public var freelanceMinutes = 20
    public var jobMinutes = 30
    public var aiEngine = AIEngineSettings()
    public var updated = ""
    public var verifiedEngine: AIEngineKind?
    public var setupDismissed = false

    public init() {}

    enum CodingKeys: String, CodingKey {
        case ownerName, sources, channelOwner, botUsername, autoFreelance, autoJobs, autoEmails
        case freelanceMinutes, jobMinutes, aiEngine, updated, verifiedEngine, setupDismissed
    }

    struct LegacyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ownerName = try container.decodeIfPresent(String.self, forKey: .ownerName) ?? Config.placeholderOwnerName
        sources = try container.decodeIfPresent([String: Bool].self, forKey: .sources) ?? [:]
        channelOwner = (try? container.decodeIfPresent(ChannelOwner.self, forKey: .channelOwner)) ?? nil
        botUsername = try container.decodeIfPresent(String.self, forKey: .botUsername) ?? ""
        autoFreelance = try container.decodeIfPresent(Bool.self, forKey: .autoFreelance) ?? false
        autoJobs = try container.decodeIfPresent(Bool.self, forKey: .autoJobs) ?? false
        autoEmails = try container.decodeIfPresent(Bool.self, forKey: .autoEmails) ?? false
        freelanceMinutes = max(15, try container.decodeIfPresent(Int.self, forKey: .freelanceMinutes) ?? 20)
        jobMinutes = max(20, try container.decodeIfPresent(Int.self, forKey: .jobMinutes) ?? 30)
        aiEngine = try container.decodeIfPresent(AIEngineSettings.self, forKey: .aiEngine) ?? AIEngineSettings()
        updated = try container.decodeIfPresent(String.self, forKey: .updated) ?? ""
        verifiedEngine = try container.decodeIfPresent(AIEngineKind.self, forKey: .verifiedEngine)
        setupDismissed = try container.decodeIfPresent(Bool.self, forKey: .setupDismissed) ?? false

        let legacy = try decoder.container(keyedBy: LegacyKey.self)
        for id in Self.freelanceSources + Self.jobSources where sources[id] == nil {
            if let value = try legacy.decodeIfPresent(Bool.self, forKey: LegacyKey(stringValue: id)) {
                sources[id] = value
            }
        }
        let linkedChat = try legacy.decodeIfPresent(Int64.self, forKey: LegacyKey(stringValue: "chatId")) ?? 0
        if channelOwner == nil && linkedChat > 0 {
            channelOwner = ChannelOwner(userId: linkedChat, chatId: linkedChat, name: "")
        }
        if let value = try legacy.decodeIfPresent(Bool.self, forKey: LegacyKey(stringValue: "autoCorreos")) {
            autoEmails = value
        }
    }

    public var chatId: Int64 { channelOwner?.chatId ?? 0 }

    public func isEnabled(_ source: String) -> Bool { sources[source] ?? true }

    public mutating func setEnabled(_ source: String, _ value: Bool) { sources[source] = value }

    public var freelanceOn: Bool { Self.freelanceSources.contains { isEnabled($0) } }
    public var jobsOn: Bool { Self.jobSources.contains { isEnabled($0) } }
}
