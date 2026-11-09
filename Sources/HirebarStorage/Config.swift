import Foundation
import HirebarApplication
import HirebarDomain

extension Config {
    public static func load() -> Config {
        guard let data = try? Data(contentsOf: Paths.config),
              let config = try? JSONDecoder().decode(Config.self, from: data) else { return Config() }
        return config
    }

    public func save() {
        Paths.ensure()
        var copy = self
        copy.updated = ISO8601DateFormatter().string(from: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(copy) { try? data.write(to: Paths.config, options: .atomic) }
    }
}
