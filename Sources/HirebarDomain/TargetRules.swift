public struct TargetRules: Hashable, Sendable {
    public let ignoredQueryParameters: Set<String>
    public let ignoredQueryParameterPrefixes: [String]
    public let networks: Set<String>
    public let webSchemes: Set<String>

    public init(
        ignoredQueryParameters: Set<String>,
        ignoredQueryParameterPrefixes: [String],
        networks: Set<String>,
        webSchemes: Set<String>
    ) {
        self.ignoredQueryParameters = Set(ignoredQueryParameters.map { $0.lowercased() })
        self.ignoredQueryParameterPrefixes = ignoredQueryParameterPrefixes.map { $0.lowercased() }
        self.networks = Set(networks.map { $0.lowercased() })
        self.webSchemes = Set(webSchemes.map { $0.lowercased() })
    }

    public static let strict = TargetRules(
        ignoredQueryParameters: [], ignoredQueryParameterPrefixes: [], networks: [], webSchemes: ["https", "http"])

    func ignores(_ parameter: String) -> Bool {
        let name = parameter.lowercased()
        return ignoredQueryParameters.contains(name) || ignoredQueryParameterPrefixes.contains { name.hasPrefix($0) }
    }
}
