import Foundation
import HirebarAI
import HirebarApplication
import HirebarDomain
import HirebarMedia
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

public final class Engine {
    public let telegram: Telegram
    public let controller: Controller
    public let jobRadar: JobRadar
    public let freelanceRadar: FreelanceRadar
    public let scheduler: Scheduler
    public let activity: ActivityRepository
    let runState: FileRunStateRepository
    let upgrades: WorkspaceUpgrades?
    let clock: Clock
    let updateFetcher = NetPageFetcher()
    let currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"

    public init(resources: EngineResources) {
        let stores = Repositories.files(searchDefaults: resources.searchDefaults, retention: resources.retention)
        activity = FileExecutionStateStore.standard
        upgrades = resources.upgrades
        let clock = SystemClock()
        self.clock = clock
        runState = FileRunStateRepository(claimRetention: resources.retention.claims)
        telegram = Telegram(secrets: KeychainSecretStore(), offsets: runState)
        let adapters = EngineAdapters(
            chat: telegram, desktop: MacDesktopNotifications(), clock: clock, aiRunner: ProcessAIRunner(), media: SystemMediaRenderer(),
            resources: resources)
        controller = Controller(stores: stores, adapters: adapters)
        let portals = PortalAccess.bundled
        jobRadar = JobRadar(stores: stores, clock: clock, portals: portals, policy: resources.policy)
        freelanceRadar = FreelanceRadar(stores: stores, clock: clock, portals: portals, policy: resources.policy)
        scheduler = Scheduler(stores: stores, clock: clock, policy: resources.policy)
        jobRadar.controller = controller
        freelanceRadar.controller = controller
        scheduler.controller = controller
        scheduler.jobRadar = jobRadar
        scheduler.freelanceRadar = freelanceRadar
        controller.scheduler = scheduler
        controller.jobRadar = jobRadar
        controller.freelanceRadar = freelanceRadar
    }

    public func start(resources: URL?) {
        WorkspaceMigration.run(runState: runState, upgrades: upgrades)
        Paths.installTemplates(from: resources)
        AudioTools.removeLegacyCopy()
        controller.stores.agents.writeMissingDefaults()
        controller.start()
        freelanceRadar.start()
        jobRadar.start()
        scheduler.start()
        scheduleUpdateCheck()
        Log.write("Hirebar iniciado")
    }

    private static let updateCheckInterval: TimeInterval = 86_400

    private func scheduleUpdateCheck() {
        let check: @MainActor () -> Void = { [weak controller, updateFetcher, currentVersion] in
            controller?.checkForUpdate(current: currentVersion, fetcher: updateFetcher)
        }
        check()
        _ = clock.every(Self.updateCheckInterval, tolerance: 3_600, check)
    }
}
