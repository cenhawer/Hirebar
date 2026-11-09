import Foundation
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

public enum Engine {
    public static func start(resources: URL?) {
        Telegram.shared = Telegram(secrets: KeychainSecretStore())
        Paths.ensure()
        Paths.installTemplates(from: resources)
        AudioTools.removeLegacyCopy()
        AgentStore.writeMissingDefaults()
        Controller.shared.start()
        FreelanceRadar.shared.start()
        JobRadar.shared.start()
        Scheduler.shared.start()
        Log.write("Hirebar iniciado")
    }
}
