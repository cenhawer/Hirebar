import Foundation

public struct WorkspaceUpgrades: Decodable, Sendable {
    public static let fileName = "migraciones"
    static let supportedSchemaVersion = 1

    public struct FreelanceLoosening: Decodable, Sendable {
        public let quitarDeTitleNever: [String]
        public let quitarDeOffProfile: [String]
        public let agregarAStretch: [String]
        public let cupoDiarioMinimo: Int

        public init(quitarDeTitleNever: [String], quitarDeOffProfile: [String], agregarAStretch: [String], cupoDiarioMinimo: Int) {
            self.quitarDeTitleNever = quitarDeTitleNever
            self.quitarDeOffProfile = quitarDeOffProfile
            self.agregarAStretch = agregarAStretch
            self.cupoDiarioMinimo = cupoDiarioMinimo
        }
    }

    public let schemaVersion: Int
    public let freelanceMasAbierto: FreelanceLoosening

    public init(freelanceMasAbierto: FreelanceLoosening) {
        schemaVersion = Self.supportedSchemaVersion
        self.freelanceMasAbierto = freelanceMasAbierto
    }

    public static func decode(_ data: Data) throws -> WorkspaceUpgrades {
        let upgrades = try JSONDecoder().decode(WorkspaceUpgrades.self, from: data)
        guard upgrades.schemaVersion == supportedSchemaVersion else { throw ResourceFailure.unsupportedVersion(upgrades.schemaVersion) }
        guard upgrades.freelanceMasAbierto.cupoDiarioMinimo > 0 else { throw ResourceFailure.invalidValues }
        return upgrades
    }
}
