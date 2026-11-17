import AppKit
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

func installEditMenu(in app: NSApplication) {
    let mainMenu = NSMenu()
    let editItem = NSMenuItem()
    mainMenu.addItem(editItem)
    let editMenu = NSMenu(title: String(localized: "Edición"))
    editMenu.addItem(withTitle: String(localized: "Deshacer"), action: Selector(("undo:")), keyEquivalent: "z")
    let redo = editMenu.addItem(withTitle: String(localized: "Rehacer"), action: Selector(("redo:")), keyEquivalent: "Z")
    redo.keyEquivalentModifierMask = [.command, .shift]
    editMenu.addItem(.separator())
    editMenu.addItem(withTitle: String(localized: "Cortar"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: String(localized: "Copiar"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: String(localized: "Pegar"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: String(localized: "Seleccionar todo"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editItem.submenu = editMenu
    app.mainMenu = mainMenu
}

let app = NSApplication.shared
do {
    let delegate = AppDelegate(engine: Engine(resources: try EngineResources.bundled()))
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    installEditMenu(in: app)
    app.run()
} catch {
    let alert = NSAlert()
    alert.messageText = String(localized: "Hirebar está incompleto")
    alert.informativeText = String(localized: "Faltan archivos dentro de la app. Vuelve a instalarla con scripts/bundle.sh --install.")
    alert.runModal()
}
