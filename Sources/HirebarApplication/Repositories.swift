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

    public init(
        config: ConfigRepository,
        batches: BatchRepository,
        agents: AgentRepository,
        contentAccounts: ContentAccountRepository,
        metrics: MetricsRepository,
        profile: ProfileRepository,
        quotas: QuotaRepository,
        portals: PortalRepository
    ) {
        self.config = config
        self.batches = batches
        self.agents = agents
        self.contentAccounts = contentAccounts
        self.metrics = metrics
        self.profile = profile
        self.quotas = quotas
        self.portals = portals
    }
}
