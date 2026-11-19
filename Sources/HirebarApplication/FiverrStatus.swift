import Foundation

extension Config {
    public var fiverrStatus: String {
        isEnabled(Self.fiverr)
            ? String(localized: "Fiverr: mensajes y pedidos en los seguimientos") : String(localized: "Fiverr: apagado")
    }
}
