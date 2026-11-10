import AppKit
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

enum AutoSendConfirmation {
    static let origin = String(localized: "la Mac")
    static let settingsOrigin = "Ajustes"

    static func ask(_ kinds: [AgentKind], agents: AgentRepository) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = String(localized: "¿Prender el envío automático?")
        alert.informativeText = AutoSend.explanation(for: kinds, agents: agents)
        alert.addButton(withTitle: String(localized: "Prender"))
        alert.addButton(withTitle: String(localized: "Cancelar"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func toggle(_ kind: AgentKind, agents: AgentRepository) {
        if AgentStore.load(kind).autoApprove {
            AutoSend.turnOff(kind, from: origin, agents: agents)
        } else if ask([kind], agents: agents) {
            AutoSend.turnOn(kind, from: origin, agents: agents)
        }
    }
}
