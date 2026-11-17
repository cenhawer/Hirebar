import Foundation

public enum Target: Hashable, Sendable {
    case url(String)
    case email(String)
    case account(network: String, handle: String)

    public func normalized(using rules: TargetRules) -> Target {
        switch self {
        case .url(let address):
            return .url(Self.normalizedAddress(address, rules: rules))
        case .email(let address):
            return .email(address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        case .account(let network, let handle):
            let bareHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return .account(
                network: network.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                handle: bareHandle.hasPrefix("@") ? String(bareHandle.dropFirst()) : bareHandle
            )
        }
    }

    public var displayText: String {
        switch self {
        case .url(let address): return address
        case .email(let address): return address
        case .account(let network, let handle): return "\(network): \(handle)"
        }
    }

    public func matches(_ other: Target, using rules: TargetRules) -> Bool {
        normalized(using: rules) == other.normalized(using: rules)
    }

    public func isValid(using rules: TargetRules) -> Bool {
        switch normalized(using: rules) {
        case .url:
            guard case .url(let address) = self, let components = Self.webComponents(address) else { return false }
            return rules.webSchemes.contains((components.scheme ?? "").lowercased())
        case .email(let address):
            return Self.isEmailAddress(address)
        case .account(let network, let handle):
            return rules.networks.contains(network) && !handle.isEmpty && !handle.contains(where: \.isWhitespace)
        }
    }

    static func webComponents(_ address: String) -> URLComponents? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let components = URLComponents(string: withScheme), let host = components.host, host.contains(".") else { return nil }
        return components
    }

    static func isEmailAddress(_ address: String) -> Bool {
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !address.contains(where: \.isWhitespace) else { return false }
        let domain = parts[1]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    static func normalizedAddress(_ address: String, rules: TargetRules) -> String {
        guard let components = webComponents(address), let host = components.host else {
            return address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        var path = components.percentEncodedPath
        while path.hasSuffix("/") { path.removeLast() }
        let query = (components.percentEncodedQueryItems ?? [])
            .filter { !rules.ignores($0.name) }
            .map { item in item.value.map { "\(item.name)=\($0)" } ?? item.name }
            .sorted()
        let fragment = components.percentEncodedFragment ?? ""
        var result = host.lowercased().replacingOccurrences(of: "www.", with: "", options: .anchored) + path
        if !query.isEmpty { result += "?" + query.joined(separator: "&") }
        if fragment.hasPrefix("/") || fragment.hasPrefix("!/") { result += "#" + fragment }
        return result
    }
}

extension Target: Codable {
    private enum CodingKeys: String, CodingKey {
        case url
        case email
        case network
        case handle
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let shapes = [container.contains(.url), container.contains(.email), container.contains(.network) || container.contains(.handle)]
        guard shapes.filter({ $0 }).count == 1 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "target must have exactly one shape"))
        }
        if let address = try container.decodeIfPresent(String.self, forKey: .url) {
            self = .url(address)
        } else if let address = try container.decodeIfPresent(String.self, forKey: .email) {
            self = .email(address)
        } else {
            self = .account(
                network: try container.decode(String.self, forKey: .network),
                handle: try container.decode(String.self, forKey: .handle)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .url(let address):
            try container.encode(address, forKey: .url)
        case .email(let address):
            try container.encode(address, forKey: .email)
        case .account(let network, let handle):
            try container.encode(network, forKey: .network)
            try container.encode(handle, forKey: .handle)
        }
    }
}
