import Foundation
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
        telegram = Telegram(secrets: KeychainSecretStore())
        controller = Controller(telegram: telegram, stores: stores)
        jobRadar = JobRadar(stores: stores)
        freelanceRadar = FreelanceRadar(stores: stores)
        scheduler = Scheduler(stores: stores)
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
