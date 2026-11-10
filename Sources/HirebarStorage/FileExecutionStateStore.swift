import Foundation
import HirebarApplication
import HirebarDomain

public struct FileExecutionStateStore: ExecutionStateStore {
    public static let currentSchemaVersion = 1

    let stateFolder: URL
    let runsFolder: URL
    let now: @Sendable () -> Date

    public init(stateFolder: URL = Paths.state, runsFolder: URL = Paths.runs, now: @escaping @Sendable () -> Date = Date.init) {
        self.stateFolder = stateFolder
        self.runsFolder = runsFolder
        self.now = now
    }

    public static var standard: FileExecutionStateStore { FileExecutionStateStore() }

    private struct Versioned<Content: Codable>: Codable {
        let schemaVersion: Int
        let content: Content
    }

    struct StoredApproval: Codable {
        let agent: AgentID
        let items: [ApprovedItem]
    }

    struct StoredVerification: Codable {
        let agent: AgentID
        let verifiedAt: Date
        let verification: ExecutionVerification
    }

    var proposalsFolder: URL { stateFolder.appendingPathComponent("propuestas", isDirectory: true) }
    var approvedFolder: URL { stateFolder.appendingPathComponent("aprobados", isDirectory: true) }
    var verificationsFolder: URL { stateFolder.appendingPathComponent("verificaciones", isDirectory: true) }
    var pausesFile: URL { stateFolder.appendingPathComponent("pausas.json") }
    var seenFile: URL { stateFolder.appendingPathComponent("vistos.json") }

    public static func actionLogFile(batch: String, in runsFolder: URL = Paths.runs) -> URL {
        runsFolder.appendingPathComponent(ActionLogFile.name(batch: batch))
    }

    public func proposals(batch: String) -> [Proposal] {
        read([Proposal].self, from: proposalsFolder.appendingPathComponent("\(batch).json")) ?? []
    }

    public func saveProposals(_ proposals: [Proposal], batch: String) throws {
        try write(proposals, to: proposalsFolder.appendingPathComponent("\(batch).json"))
    }

    public func approvedItems(batch: String) -> [ApprovedItem] {
        read(StoredApproval.self, from: approvedFolder.appendingPathComponent("\(batch).json"))?.items ?? []
    }

    public func saveApproved(_ items: [ApprovedItem], batch: String, agent: AgentID) throws {
        try write(StoredApproval(agent: agent, items: items), to: approvedFolder.appendingPathComponent("\(batch).json"))
    }

    public func releaseApproval(batch: String) throws {
        try removeIfPresent(approvedFolder.appendingPathComponent("\(batch).json"))
    }

    public func actionLog(batch: String) -> ActionLogReading {
        let file = Self.actionLogFile(batch: batch, in: runsFolder)
        guard let data = try? Data(contentsOf: file) else { return .missing }
        guard let log = try? Self.decoder.decode(ActionLog.self, from: data) else { return .invalid }
        return .found(log)
    }

    public func discardActionLog(batch: String) throws {
        try removeIfPresent(Self.actionLogFile(batch: batch, in: runsFolder))
    }

    public func save(_ verification: ExecutionVerification, agent: AgentID) throws {
        let stored = StoredVerification(agent: agent, verifiedAt: now(), verification: verification)
        try write(stored, to: verificationsFolder.appendingPathComponent("\(verification.batch).json"))
    }

    public func consumedActions(agent: AgentID, since: Date) -> Int {
        let verifications = storedVerifications().filter { $0.agent == agent }
        let verifiedBatches = Set(verifications.map(\.verification.batch))
        let sent = verifications.filter { $0.verifiedAt >= since }
            .flatMap(\.verification.verdicts)
            .filter { $0.record?.outcome == .done }
            .count
        let reserved = storedApprovals()
            .filter { $0.agent == agent }
            .flatMap(\.items)
            .filter { !verifiedBatches.contains($0.batch) && $0.approvedAt >= since }
            .count
        return sent + reserved
    }

    public func contactedTargets(agent: AgentID) -> [Target] {
        storedVerifications().filter { $0.agent == agent }
            .flatMap(\.verification.verdicts)
            .filter { $0.status == .authorized && $0.record?.outcome == .done }
            .compactMap { $0.record?.target }
    }

    public func seenProposals() -> [String: Date] {
        read([String: Date].self, from: seenFile) ?? [:]
    }

    public func saveSeenProposals(_ seen: [String: Date]) throws {
        try write(seen, to: seenFile)
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

    public func removeRecords(before date: Date) throws {
        for folder in [proposalsFolder, approvedFolder, verificationsFolder] {
            let keys: [URLResourceKey] = [.contentModificationDateKey]
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)) ?? []
            for file in files {
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? date
                if modified < date { try FileManager.default.removeItem(at: file) }
            }
        }
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

    func storedVerifications() -> [StoredVerification] {
        files(in: verificationsFolder).compactMap { read(StoredVerification.self, from: $0) }
    }

    func storedApprovals() -> [StoredApproval] {
        files(in: approvedFolder).compactMap { read(StoredApproval.self, from: $0) }
    }

    func files(in folder: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
    }

    func removeIfPresent(_ file: URL) throws {
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        try FileManager.default.removeItem(at: file)
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
