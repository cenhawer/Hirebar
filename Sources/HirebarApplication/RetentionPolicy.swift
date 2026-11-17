import Foundation

public struct RetentionPolicy: Decodable, Sendable {
    public static let fileName = "retencion"
    static let supportedSchemaVersion = 1
    static let secondsPerDay: TimeInterval = 86400

    public let schemaVersion: Int
    public let ejecucionesDias: Int
    public let listasDias: Int
    public let turnosDias: Int
    public let seguimientosTerminadosDias: Int
    public let metricasSemanas: Int
    public let eventosDias: Int
    public let informesDias: Int
    public let grabacionesDias: Int
    public let videosDias: Int
    public let descartadosDias: Int
    public let historialMaximoBytes: Int
    public let historialConservaBytes: Int

    static func days(_ count: Int) -> TimeInterval { TimeInterval(count) * secondsPerDay }

    public var runs: TimeInterval { Self.days(ejecucionesDias) }
    public var batches: TimeInterval { Self.days(listasDias) }
    public var claims: TimeInterval { Self.days(turnosDias) }
    public var finishedFollowUps: TimeInterval { Self.days(seguimientosTerminadosDias) }
    public var events: TimeInterval { Self.days(eventosDias) }
    public var reports: TimeInterval { Self.days(informesDias) }
    public var recordings: TimeInterval { Self.days(grabacionesDias) }
    public var videos: TimeInterval { Self.days(videosDias) }
    public var discarded: TimeInterval { Self.days(descartadosDias) }

    var positiveValues: [Int] {
        [
            ejecucionesDias, listasDias, turnosDias, seguimientosTerminadosDias, metricasSemanas, eventosDias, informesDias,
            grabacionesDias, videosDias, descartadosDias, historialConservaBytes,
        ]
    }

    public static func decode(_ data: Data) throws -> RetentionPolicy {
        let policy = try JSONDecoder().decode(RetentionPolicy.self, from: data)
        guard policy.schemaVersion == supportedSchemaVersion else { throw ResourceFailure.unsupportedVersion(policy.schemaVersion) }
        guard policy.positiveValues.allSatisfy({ $0 > 0 }), policy.historialMaximoBytes > policy.historialConservaBytes else {
            throw ResourceFailure.invalidValues
        }
        return policy
    }
}
