import Foundation
import HirebarDomain

public protocol ConfigRepository: Sendable {
    func load() -> Config
    func save(_ config: Config)
}

public protocol BatchRepository: Sendable {
    func load() -> [Batch]
    func upsert(_ batch: Batch)
    func find(id: String) -> Batch?
    func find(messageId: Int) -> Batch?
    func latestPending() -> Batch?
}

public protocol AgentRepository: Sendable {
    func load(_ kind: AgentKind) -> AgentSettings
    func all() -> [AgentSettings]
    func save(_ settings: AgentSettings)
    func update(_ kind: AgentKind, _ change: (inout AgentSettings) -> Void)
    func writeMissingDefaults()
    func parse(_ text: String) -> AgentKind?
}

public protocol ContentAccountRepository: Sendable {
    func load() -> [ContentAccount]
    func save(_ accounts: [ContentAccount]) throws
    func defaultAccount() -> ContentAccount
    func enabled() -> [ContentAccount]
    func find(_ id: String?) -> ContentAccount?
    func match(_ word: String) -> ContentAccount?
    func hasDraft(_ account: ContentAccount) -> Bool
    func needsPerformanceCheck(_ account: ContentAccount) -> Bool
    func takeChangeRequest(_ account: ContentAccount) -> String
    func requestChange(_ account: ContentAccount, _ note: String)
    func discardDraft(_ account: ContentAccount, at date: Date)
    func draftText(_ account: ContentAccount) -> String?
    func videoDescription(_ account: ContentAccount) -> String?
    func hasVideoScript(_ account: ContentAccount) -> Bool
    func latestRecording(_ account: ContentAccount) -> URL?
    func slideImages(_ account: ContentAccount) -> [URL]
    func videoPreview(_ account: ContentAccount) -> URL?
}

public protocol MetricsRepository: Sendable {
    func bump(_ mode: Mode, _ key: String, _ amount: Int)
    func event(_ text: String)
}

public protocol ProfileRepository: Sendable {
    func load() -> Profile
    func saveSkills(_ skills: [Skill]) throws
    func setSkill(_ name: String, level: SkillLevel) -> SkillChange
    func effectiveSearch() -> SearchProfile
    func pastEmployers() -> [String]
    func achievements() -> [String]
    func appendChangeRequest(_ kind: String, _ text: String, at date: Date)
    func changeRequests() -> String
    func clearChangeRequests()
}

public protocol ProspectingRepository: Sendable {
    func pendingEmails() -> Data?
    func discardPendingEmails(at date: Date)
}

public protocol WorkspaceRepository: Sendable {
    func prepare()
    func cleanUp()
}

public protocol PracticeLogRepository: Sendable {
    func record(batch: String, agent: String, at date: Date, wouldSend: [Proposal]) throws
}

public protocol RunStateRepository: Sendable {
    func seen(_ key: String) -> [String: Date]
    func saveSeen(_ seen: [String: Date], key: String)
    func claim(_ key: String) -> Bool
    func waitingVoiceAccount() -> String?
    func setWaitingVoiceAccount(_ id: String)
}

extension MetricsRepository {
    public func bump(_ mode: Mode, _ key: String) {
        bump(mode, key, 1)
    }
}

public protocol QuotaRepository: Sendable {
    func describe(_ platform: String) -> String
    func summary() -> String
    func exhausted(_ platform: String) -> Bool
    func remaining(_ platform: String) -> Int?
}

public protocol PortalRepository: Sendable {
    func load() -> [CustomPortal]
    func save(_ portals: [CustomPortal]) throws
    func active(for agent: AgentKind) -> [CustomPortal]
}

public struct Repositories: Sendable {
    public let config: ConfigRepository
    public let batches: BatchRepository
    public let agents: AgentRepository
    public let contentAccounts: ContentAccountRepository
    public let metrics: MetricsRepository
    public let profile: ProfileRepository
    public let quotas: QuotaRepository
    public let portals: PortalRepository
    public let prospecting: ProspectingRepository
    public let runState: RunStateRepository
    public let workspace: WorkspaceRepository
    public let practice: PracticeLogRepository
    public let executionState: ExecutionStateStore

    public init(
        config: ConfigRepository,
        batches: BatchRepository,
        agents: AgentRepository,
        contentAccounts: ContentAccountRepository,
        metrics: MetricsRepository,
        profile: ProfileRepository,
        quotas: QuotaRepository,
        portals: PortalRepository,
        prospecting: ProspectingRepository,
        runState: RunStateRepository,
        workspace: WorkspaceRepository,
        practice: PracticeLogRepository,
        executionState: ExecutionStateStore
    ) {
        self.config = config
        self.batches = batches
        self.agents = agents
        self.contentAccounts = contentAccounts
        self.metrics = metrics
        self.profile = profile
        self.quotas = quotas
        self.portals = portals
        self.prospecting = prospecting
        self.runState = runState
        self.workspace = workspace
        self.practice = practice
        self.executionState = executionState
    }
}
