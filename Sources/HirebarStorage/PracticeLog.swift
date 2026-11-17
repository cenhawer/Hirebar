import Foundation
import HirebarApplication
import HirebarDomain

public struct PracticeLog: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let batch: String
    public let agent: String
    public let at: Date
    public let wouldSend: [Proposal]

    public init(batch: String, agent: String, at: Date, wouldSend: [Proposal]) {
        schemaVersion = Self.currentSchemaVersion
        self.batch = batch
        self.agent = agent
        self.at = at
        self.wouldSend = wouldSend
    }

    public static func file(batch: String, in runsFolder: URL = Paths.runs) -> URL {
        runsFolder.appendingPathComponent("\(batch).practica.json")
    }

    public func save(in runsFolder: URL = Paths.runs) throws {
        try FileManager.default.createDirectory(at: runsFolder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: Self.file(batch: batch, in: runsFolder), options: .atomic)
    }

    public static func read(batch: String, in runsFolder: URL = Paths.runs) -> PracticeLog? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: file(batch: batch, in: runsFolder)),
            let log = try? decoder.decode(PracticeLog.self, from: data), log.schemaVersion == currentSchemaVersion
        else { return nil }
        return log
    }
}
