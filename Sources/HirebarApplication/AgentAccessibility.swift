public enum AgentAccessibility {
    public static func rowLabel(
        name: String,
        enabled: Bool,
        working: Bool,
        pauseReason: String?,
        next: String
    ) -> String {
        if let pauseReason {
            return "\(name): \(String(localized: "en pausa")), \(pauseReason)"
        }
        if !enabled {
            return "\(name): \(String(localized: "apagado"))"
        }
        if working {
            return "\(name): \(String(localized: "trabajando"))"
        }
        return "\(name): \(next)"
    }

    public static func toggleLabel(name: String, enabled: Bool) -> String {
        enabled
            ? String(localized: "Encendido para \(name)")
            : String(localized: "Apagado para \(name)")
    }

    public static func telegramLabel(ready: Bool, status: String) -> String {
        ready
            ? String(localized: "Telegram conectado")
            : String(localized: "Telegram sin configurar: \(status)")
    }

    public static func engineBusyLabel(busy: Bool) -> String {
        busy ? String(localized: "La IA está ocupada") : String(localized: "La IA está libre")
    }
}
