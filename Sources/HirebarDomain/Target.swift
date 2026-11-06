import Foundation

public enum Target: Hashable, Sendable {
    case url(String)
    case email(String)
    case account(network: String, handle: String)

    public var normalized: Target {
        switch self {
        case .url(let address):
            return .url(Self.normalizedAddress(address))
        case .email(let address):
            return .email(address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        case .account(let network, let handle):
            let bareHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return .account(
                network: network.lowercased(),
                handle: bareHandle.hasPrefix("@") ? String(bareHandle.dropFirst()) : bareHandle
            )
        }
    }

    public func matches(_ other: Target) -> Bool {
        normalized == other.normalized
    }

    static func normalizedAddress(_ address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed), let host = components.host else {
            return trimmed.lowercased()
        }
        var path = components.percentEncodedPath
        while path.hasSuffix("/") { path.removeLast() }
        return host.lowercased().replacingOccurrences(of: "www.", with: "", options: .anchored) + path
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
