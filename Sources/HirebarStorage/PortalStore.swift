import Foundation
import HirebarDomain

public enum PortalStore {
    public static var url: URL { Paths.workspaceFile("portales.json") }
    public static func load() -> [CustomPortal] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([CustomPortal].self, from: data)) ?? []
    }

    public static func save(_ portals: [CustomPortal]) throws {
        Paths.ensure()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let clean = portals.filter(\.isValid).map { portal -> CustomPortal in
            var portal = portal
            portal.name = portal.name.trimmingCharacters(in: .whitespaces)
            portal.url = portal.url.trimmingCharacters(in: .whitespaces)
            return portal
        }
        try encoder.encode(clean).write(to: url, options: .atomic)
    }

    public static func active(for agent: AgentKind) -> [CustomPortal] {
        load().filter { $0.agent == agent && $0.enabled && $0.isValid }
    }

}
