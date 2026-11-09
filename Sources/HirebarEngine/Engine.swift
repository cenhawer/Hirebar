import Foundation
import HirebarApplication
import HirebarCore
import HirebarDomain

public enum Engine {
    public static func start(resources: URL?) {
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
