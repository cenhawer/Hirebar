import AppKit
import HirebarDomain
import HirebarEngine
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

enum AutoSendConfirmation {
    static let origin = "la Mac"
    static let settingsOrigin = "Ajustes"

    static func ask(_ kinds: [AgentKind]) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "¿Prender el envío automático?"
        alert.informativeText = AutoSend.explanation(for: kinds)
        alert.addButton(withTitle: "Prender")
        alert.addButton(withTitle: "Cancelar")
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func toggle(_ kind: AgentKind) {
        if AgentStore.load(kind).autoApprove {
            AutoSend.turnOff(kind, from: origin)
        } else if ask([kind]) {
            AutoSend.turnOn(kind, from: origin)
        }
    }
}
