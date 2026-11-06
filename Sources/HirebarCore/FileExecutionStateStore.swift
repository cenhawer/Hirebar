import Foundation
import HirebarApplication
import HirebarDomain

public struct FileExecutionStateStore: ExecutionStateStore {
    public static let currentSchemaVersion = 1

    let stateFolder: URL
    let runsFolder: URL

    public init(stateFolder: URL = Paths.state, runsFolder: URL = Paths.runs) {
        self.stateFolder = stateFolder
        self.runsFolder = runsFolder
    }

    public static var standard: FileExecutionStateStore { FileExecutionStateStore() }

    private struct Versioned<Content: Codable>: Codable {
        let schemaVersion: Int
        let content: Content
    }

    var proposalsFolder: URL { stateFolder.appendingPathComponent("propuestas", isDirectory: true) }
    var approvedFolder: URL { stateFolder.appendingPathComponent("aprobados", isDirectory: true) }
    var verificationsFolder: URL { stateFolder.appendingPathComponent("verificaciones", isDirectory: true) }
    var pausesFile: URL { stateFolder.appendingPathComponent("pausas.json") }

    public static func actionLogFile(batch: String, in runsFolder: URL = Paths.runs) -> URL {
        runsFolder.appendingPathComponent("\(batch).acciones.json")
    }

    public func proposals(batch: String) -> [Proposal] {
        read([Proposal].self, from: proposalsFolder.appendingPathComponent("\(batch).json")) ?? []
    }

    public func saveProposals(_ proposals: [Proposal], batch: String) throws {
        try write(proposals, to: proposalsFolder.appendingPathComponent("\(batch).json"))
    }

    public func approvedItems(batch: String) -> [ApprovedItem] {
        read([ApprovedItem].self, from: approvedFolder.appendingPathComponent("\(batch).json")) ?? []
    }

    public func saveApproved(_ items: [ApprovedItem], batch: String) throws {
        try write(items, to: approvedFolder.appendingPathComponent("\(batch).json"))
    }

    public func actionLog(batch: String) -> ActionLogReading {
        let file = Self.actionLogFile(batch: batch, in: runsFolder)
        guard let data = try? Data(contentsOf: file) else { return .missing }
        guard let log = try? Self.decoder.decode(ActionLog.self, from: data) else { return .invalid }
        return .found(log)
    }

    public func save(_ verification: ExecutionVerification) throws {
        try write(verification, to: verificationsFolder.appendingPathComponent("\(verification.batch).json"))
    }

    public func pauses() -> [AgentPause] {
        read([AgentPause].self, from: pausesFile) ?? []
    }

    public func pause(_ pause: AgentPause) throws {
        try write(pauses().filter { $0.agent != pause.agent } + [pause], to: pausesFile)
    }

    public func resume(_ agent: AgentID) throws {
        try write(pauses().filter { $0.agent != agent }, to: pausesFile)
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func read<Content: Codable>(_ type: Content.Type, from file: URL) -> Content? {
        guard let data = try? Data(contentsOf: file),
            let stored = try? Self.decoder.decode(Versioned<Content>.self, from: data),
            stored.schemaVersion == Self.currentSchemaVersion
        else { return nil }
        return stored.content
    }

    func write<Content: Codable>(_ content: Content, to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try Self.encoder.encode(Versioned(schemaVersion: Self.currentSchemaVersion, content: content))
        try data.write(to: file, options: .atomic)
    }
}
