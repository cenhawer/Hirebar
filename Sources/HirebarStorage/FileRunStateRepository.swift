import Foundation
import HirebarApplication

public final class FileRunStateRepository: RunStateRepository, ChatOffsetStore, @unchecked Sendable {
    static let lock = NSLock()
    static let claimRetention: TimeInterval = 14 * 86400

    struct Snapshot: Codable {
        var schemaVersion = WorkspaceSchema.current
        var seen: [String: [String: Date]] = [:]
        var claimed: [String: Date] = [:]
        var waitingVoiceAccount: String?
        var chatOffset = 0
    }

    let file: URL
    let now: @Sendable () -> Date

    public init(file: URL = Paths.state.appendingPathComponent("corrida.json"), now: @escaping @Sendable () -> Date = Date.init) {
        self.file = file
        self.now = now
    }

    func read() -> Snapshot {
        guard let data = try? Data(contentsOf: file) else { return Snapshot() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(Snapshot.self, from: data)) ?? Snapshot()
    }

    func change<Result>(_ body: (inout Snapshot) -> Result) -> Result {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        var snapshot = read()
        let result = body(&snapshot)
        snapshot.schemaVersion = WorkspaceSchema.current
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? encoder.encode(snapshot) { try? data.write(to: file, options: .atomic) }
        return result
    }

    func snapshot() -> Snapshot {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return read()
    }

    public func seen(_ key: String) -> [String: Date] { snapshot().seen[key] ?? [:] }

    public func saveSeen(_ seen: [String: Date], key: String) {
        change { $0.seen[key] = seen }
    }

    public func claim(_ key: String) -> Bool {
        let moment = now()
        return change { snapshot in
            snapshot.claimed = snapshot.claimed.filter { moment.timeIntervalSince($0.value) < Self.claimRetention }
            guard snapshot.claimed[key] == nil else { return false }
            snapshot.claimed[key] = moment
            return true
        }
    }

    public func waitingVoiceAccount() -> String? { snapshot().waitingVoiceAccount }

    public func setWaitingVoiceAccount(_ id: String) {
        change { $0.waitingVoiceAccount = id }
    }

    public func chatOffset() -> Int { snapshot().chatOffset }

    public func saveChatOffset(_ offset: Int) {
        change { $0.chatOffset = offset }
    }

    func absorb(seen: [String: [String: Date]], claimed: [String], waitingVoiceAccount: String?, chatOffset: Int) {
        let moment = now()
        change { snapshot in
            for (key, values) in seen { snapshot.seen[key, default: [:]].merge(values) { current, _ in current } }
            for key in claimed where snapshot.claimed[key] == nil { snapshot.claimed[key] = moment }
            if snapshot.waitingVoiceAccount == nil { snapshot.waitingVoiceAccount = waitingVoiceAccount }
            snapshot.chatOffset = max(snapshot.chatOffset, chatOffset)
        }
    }
}
