import Foundation
import HirebarDomain

public enum Practice {
    public static func set(_ kind: AgentKind, on: Bool, from origin: String, agents repository: AgentRepository) {
        repository.update(kind) { $0.practice = on }
        Log.write("Modo práctica de \(repository.load(kind).name) \(on ? "prendido" : "apagado") desde \(origin)")
    }
}
