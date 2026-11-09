public protocol SecretStore: Sendable {
    func secret(for account: String) -> String?
    func save(_ secret: String, for account: String) -> Bool
    func delete(_ account: String) -> Bool
}
