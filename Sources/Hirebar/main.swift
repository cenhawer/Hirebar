import AppKit
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

let app = NSApplication.shared
do {
    let delegate = AppDelegate(engine: Engine(resources: try EngineResources.bundled()))
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
} catch {
    let alert = NSAlert()
    alert.messageText = String(localized: "Hirebar está incompleto")
    alert.informativeText = String(localized: "Faltan archivos dentro de la app. Vuelve a instalarla con scripts/bundle.sh --install.")
    alert.runModal()
}
