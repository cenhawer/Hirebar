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

    public init() {
        let stores = Repositories.files
        let clock = SystemClock()
        telegram = Telegram(secrets: KeychainSecretStore())
        let adapters = EngineAdapters(
            chat: telegram, desktop: MacDesktopNotifications(), clock: clock, aiRunner: ProcessAIRunner(), media: SystemMediaRenderer(),
            resources: .bundled())
        controller = Controller(stores: stores, adapters: adapters)
        let portals = PortalAccess.bundled
        jobRadar = JobRadar(stores: stores, clock: clock, portals: portals)
        freelanceRadar = FreelanceRadar(stores: stores, clock: clock, portals: portals)
        scheduler = Scheduler(stores: stores, clock: clock)
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
        Paths.ensure()
        Paths.installTemplates(from: resources)
        AudioTools.removeLegacyCopy()
        controller.stores.agents.writeMissingDefaults()
        controller.start()
        freelanceRadar.start()
        jobRadar.start()
        scheduler.start()
        Log.write("Hirebar iniciado")
    }
}
