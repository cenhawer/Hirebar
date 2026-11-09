import Foundation

public struct CustomPortal: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var agent: AgentKind
    public var url: String
    public var notes: String
    public var enabled: Bool

    public init(id: String = UUID().uuidString, name: String, agent: AgentKind, url: String, notes: String = "", enabled: Bool = true) {
        self.id = id
        self.name = name
        self.agent = agent
        self.url = url
        self.notes = notes
        self.enabled = enabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        agent = try c.decodeIfPresent(AgentKind.self, forKey: .agent) ?? .jobs
        url = try c.decode(String.self, forKey: .url)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }

    public var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty,
              let parsed = URL(string: url.trimmingCharacters(in: .whitespaces)),
              let scheme = parsed.scheme?.lowercased() else { return false }
        return (scheme == "https" || scheme == "http") && parsed.host != nil
    }
}
