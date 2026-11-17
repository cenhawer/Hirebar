import Foundation
import HirebarApplication
import HirebarStorage

final class MemoryRunState: RunStateRepository, @unchecked Sendable {
    private var seenByKey: [String: [String: Date]] = [:]
    private var claimed: Set<String> = []
    private var waiting: String?

    func seen(_ key: String) -> [String: Date] { seenByKey[key] ?? [:] }
    func saveSeen(_ seen: [String: Date], key: String) { seenByKey[key] = seen }
    func claim(_ key: String) -> Bool { claimed.insert(key).inserted }
    func waitingVoiceAccount() -> String? { waiting }
    func setWaitingVoiceAccount(_ id: String) { waiting = id }
}

final class RecordingWorkspace: WorkspaceRepository, @unchecked Sendable {
    private(set) var cleanUps = 0
    func prepare() { Paths.ensure() }
    func cleanUp() { cleanUps += 1 }
}

extension Repositories {
    static func forTests(
        runState: RunStateRepository = MemoryRunState(), workspace: WorkspaceRepository = RecordingWorkspace()
    ) -> Repositories {
        let files = Repositories.files(
            searchDefaults: Controller.repositorySearchDefaults, retention: Controller.repositoryRetention)
        return Repositories(
            config: files.config, batches: files.batches, agents: files.agents, contentAccounts: files.contentAccounts,
            metrics: files.metrics, profile: files.profile, quotas: files.quotas, portals: files.portals,
            prospecting: files.prospecting, runState: runState, workspace: workspace, practice: files.practice,
            executionState: files.executionState)
    }
}
