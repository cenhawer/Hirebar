import Foundation

public struct PlatformQuota: Codable, Sendable {
    public var restantes: Int?
    public var total: Int?
    public var renueva: String?
    public var revisado: String?
}
