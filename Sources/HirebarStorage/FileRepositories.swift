import Foundation
import HirebarApplication
import HirebarDomain

public struct FileConfigRepository: ConfigRepository {
    public init() {}
    public func load() -> Config { Config.load() }
    public func save(_ config: Config) { config.save() }
}

public struct FileBatchRepository: BatchRepository {
    let retention: TimeInterval

    public init(retention: TimeInterval) {
        self.retention = retention
    }

    public func load() -> [Batch] { BatchStore.load() }
    public func upsert(_ batch: Batch) { BatchStore.upsert(batch, keeping: retention) }
    public func find(id: String) -> Batch? { BatchStore.find(id: id) }
    public func find(messageId: Int) -> Batch? { BatchStore.find(messageId: messageId) }
    public func latestPending() -> Batch? { BatchStore.latestPending() }
}

public struct FileAgentRepository: AgentRepository {
    public init() {}
    public func load(_ kind: AgentKind) -> AgentSettings { AgentStore.load(kind) }
    public func all() -> [AgentSettings] { AgentStore.all() }
    public func save(_ settings: AgentSettings) { AgentStore.save(settings) }
    public func update(_ kind: AgentKind, _ change: (inout AgentSettings) -> Void) { AgentStore.update(kind, change) }
    public func writeMissingDefaults() { AgentStore.writeMissingDefaults() }
    public func parse(_ text: String) -> AgentKind? { AgentKind.parse(text) }
}

public struct FileContentAccountRepository: ContentAccountRepository {
    public init() {}
    public func load() -> [ContentAccount] { ContentAccountStore.load() }
    public func save(_ accounts: [ContentAccount]) throws { try ContentAccountStore.save(accounts) }
    public func defaultAccount() -> ContentAccount { ContentAccountStore.defaultAccount() }
    public func enabled() -> [ContentAccount] { ContentAccountStore.enabled() }
    public func find(_ id: String?) -> ContentAccount? { ContentAccountStore.find(id) }
    public func match(_ word: String) -> ContentAccount? { ContentAccountStore.match(word) }
    public func hasDraft(_ account: ContentAccount) -> Bool { account.hasDraft }
    public func needsPerformanceCheck(_ account: ContentAccount) -> Bool { account.needsPerformanceCheck }
    public func takeChangeRequest(_ account: ContentAccount) -> String { ContentAccountFiles.takeChangeRequest(account) }
    public func requestChange(_ account: ContentAccount, _ note: String) { ContentAccountFiles.requestChange(account, note) }
    public func discardDraft(_ account: ContentAccount, at date: Date) { ContentAccountFiles.discardDraft(account, at: date) }
    public func draftText(_ account: ContentAccount) -> String? { ContentAccountFiles.copyableText(account.draft) }
    public func videoDescription(_ account: ContentAccount) -> String? { ContentAccountFiles.copyableText(account.videoDescription) }
    public func hasVideoScript(_ account: ContentAccount) -> Bool { ContentAccountFiles.hasVideoScript(account) }
    public func latestRecording(_ account: ContentAccount) -> URL? { ContentAccountFiles.latestRecording(account) }
}

public struct FileMetricsRepository: MetricsRepository {
    public init() {}
    public func bump(_ mode: Mode, _ key: String, _ amount: Int) { Metrics.bump(mode, key, amount) }
    public func event(_ text: String) { Metrics.event(text) }
}

public struct FileProfileRepository: ProfileRepository {
    let url: URL
    let searchDefaults: SearchProfile

    public init(url: URL = Profile.url, searchDefaults: SearchProfile) {
        self.url = url
        self.searchDefaults = searchDefaults
    }

    public func pastEmployers() -> [String] { ProfileExperience.pastEmployers(from: url) }
    public func achievements() -> [String] { ProfileExperience.achievements(from: url) }
    public func load() -> Profile { Profile.load() }
    public func saveSkills(_ skills: [Skill]) throws { try ProfileEditor.saveSkills(skills) }
    public func setSkill(_ name: String, level: SkillLevel) -> SkillChange { ProfileEditor.setSkill(name, level: level) }
    public func effectiveSearch() -> SearchProfile { SearchProfile.loadEffective(defaults: searchDefaults) }
    public func appendChangeRequest(_ kind: String, _ text: String, at date: Date) { ProfileRequests.append(kind, text, at: date) }
    public func changeRequests() -> String { ProfileRequests.read() }
    public func clearChangeRequests() { ProfileRequests.clear() }
}

public struct FileQuotaRepository: QuotaRepository {
    public init() {}
    public func describe(_ platform: String) -> String { Quotas.describe(platform) }
    public func summary() -> String { Quotas.summary() }
    public func exhausted(_ platform: String) -> Bool { Quotas.exhausted(platform) }
    public func remaining(_ platform: String) -> Int? { Quotas.remaining(platform) }
}

public struct FilePortalRepository: PortalRepository {
    public init() {}
    public func load() -> [CustomPortal] { PortalStore.load() }
    public func save(_ portals: [CustomPortal]) throws { try PortalStore.save(portals) }
    public func active(for agent: AgentKind) -> [CustomPortal] { PortalStore.active(for: agent) }
}

public struct FileWorkspaceRepository: WorkspaceRepository {
    let retention: RetentionPolicy

    public init(retention: RetentionPolicy) {
        self.retention = retention
    }

    public func prepare() { Paths.ensure() }
    public func cleanUp() { Housekeeping.run(policy: retention) }
}

public struct FilePracticeLogRepository: PracticeLogRepository {
    public init() {}
    public func record(batch: String, agent: String, at date: Date, wouldSend: [Proposal]) throws {
        try PracticeLog(batch: batch, agent: agent, at: date, wouldSend: wouldSend).save()
    }
}

extension Repositories {
    public static func files(searchDefaults: SearchProfile, retention: RetentionPolicy) -> Repositories {
        Repositories(
            config: FileConfigRepository(), batches: FileBatchRepository(retention: retention.batches), agents: FileAgentRepository(),
            contentAccounts: FileContentAccountRepository(), metrics: FileMetricsRepository(),
            profile: FileProfileRepository(searchDefaults: searchDefaults),
            quotas: FileQuotaRepository(), portals: FilePortalRepository(), prospecting: FileProspectingRepository(),
            runState: FileRunStateRepository(claimRetention: retention.claims),
            workspace: FileWorkspaceRepository(retention: retention), practice: FilePracticeLogRepository(),
            executionState: FileExecutionStateStore.standard)
    }
}
