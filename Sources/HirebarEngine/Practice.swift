import Foundation
import HirebarApplication
import HirebarCore
import HirebarDomain

public enum Practice {
    public static func set(_ kind: AgentKind, on: Bool, from origin: String) {
        AgentStore.update(kind) { $0.practice = on }
        Log.write("Modo práctica de \(AgentStore.load(kind).name) \(on ? "prendido" : "apagado") desde \(origin)")
    }
}
