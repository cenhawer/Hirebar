import Foundation

public struct EnginePolicy: Decodable, Sendable {
    public static let fileName = "motor"
    static let supportedSchemaVersion = 1
    static let secondsPerMinute: TimeInterval = 60
    static let secondsPerDay: TimeInterval = 86400

    public struct Runs: Decodable, Sendable {
        let maximoMinutos: Int
        let avisoSesionVencidaMinutos: Int
        let vigilanciaSegundos: Int
        let recuperacionSegundos: Int
        let propuestasVistasDias: Int

        public var maximum: TimeInterval { TimeInterval(maximoMinutos) * EnginePolicy.secondsPerMinute }
        public var expiredSessionAlert: TimeInterval { TimeInterval(avisoSesionVencidaMinutos) * EnginePolicy.secondsPerMinute }
        public var watchdog: TimeInterval { TimeInterval(vigilanciaSegundos) }
        public var recoveryDelay: TimeInterval { TimeInterval(recuperacionSegundos) }
        public var proposalSeenWindow: TimeInterval { TimeInterval(propuestasVistasDias) * EnginePolicy.secondsPerDay }
    }

    public struct JobRadar: Decodable, Sendable {
        let primeraBusquedaSegundos: Int
        let vistosDias: Int
        public let revisadasPorBusqueda: Int
        public let fuertesPorLista: Int
        public let retoPorLista: Int

        public var firstDelay: TimeInterval { TimeInterval(primeraBusquedaSegundos) }
        public var seenWindow: TimeInterval { TimeInterval(vistosDias) * EnginePolicy.secondsPerDay }
    }

    public struct FreelanceRadar: Decodable, Sendable {
        let primeraBusquedaSegundos: Int
        let vistosDias: Int
        public let proyectosPorLista: Int

        public var firstDelay: TimeInterval { TimeInterval(primeraBusquedaSegundos) }
        public var seenWindow: TimeInterval { TimeInterval(vistosDias) * EnginePolicy.secondsPerDay }
    }

    public struct Radars: Decodable, Sendable {
        let revisionSegundos: Int
        let toleranciaSegundos: Int
        public let empleo: JobRadar
        public let freelance: FreelanceRadar

        public var tick: TimeInterval { TimeInterval(revisionSegundos) }
        public var tolerance: TimeInterval { TimeInterval(toleranciaSegundos) }
    }

    public struct Scheduler: Decodable, Sendable {
        let revisionSegundos: Int
        let toleranciaSegundos: Int
        let primeraRevisionSegundos: Int
        public let horaLimpiezaDomingo: Int

        public var tick: TimeInterval { TimeInterval(revisionSegundos) }
        public var tolerance: TimeInterval { TimeInterval(toleranciaSegundos) }
        public var firstTick: TimeInterval { TimeInterval(primeraRevisionSegundos) }
    }

    public let schemaVersion: Int
    public let corridas: Runs
    public let radares: Radars
    public let programador: Scheduler

    var positiveValues: [Int] {
        [
            corridas.maximoMinutos, corridas.avisoSesionVencidaMinutos, corridas.vigilanciaSegundos, corridas.propuestasVistasDias,
            radares.revisionSegundos, radares.empleo.vistosDias, radares.empleo.revisadasPorBusqueda, radares.empleo.fuertesPorLista,
            radares.freelance.vistosDias, radares.freelance.proyectosPorLista, programador.revisionSegundos,
        ]
    }

    public static func decode(_ data: Data) throws -> EnginePolicy {
        let policy = try JSONDecoder().decode(EnginePolicy.self, from: data)
        guard policy.schemaVersion == supportedSchemaVersion else { throw ResourceFailure.unsupportedVersion(policy.schemaVersion) }
        guard policy.positiveValues.allSatisfy({ $0 > 0 }), (0...23).contains(policy.programador.horaLimpiezaDomingo) else {
            throw ResourceFailure.invalidValues
        }
        return policy
    }
}
