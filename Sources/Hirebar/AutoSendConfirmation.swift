import AppKit
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

enum AutoSendConfirmation {
    static let origin = "la Mac"
    static let settingsOrigin = "Ajustes"

    static func ask(_ kinds: [AgentKind], agents: AgentRepository) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "¿Prender el envío automático?"
        alert.informativeText = AutoSend.explanation(for: kinds, agents: agents)
        alert.addButton(withTitle: "Prender")
        alert.addButton(withTitle: "Cancelar")
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
