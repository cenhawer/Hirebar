import HirebarApplication
import XCTest

final class AgentAccessibilityTests: XCTestCase {
    func testOffRow() {
        let label = AgentAccessibility.rowLabel(name: "Empleo", enabled: false, working: false, pauseReason: nil, next: "mañana")
        XCTAssertEqual(label, "Empleo: apagado")
    }

    func testPausedRow() {
        let label = AgentAccessibility.rowLabel(
            name: "Freelance", enabled: true, working: false, pauseReason: "cupo agotado", next: "mañana"
        )
        XCTAssertEqual(label, "Freelance: en pausa, cupo agotado")
    }

    func testWorkingRow() {
        let label = AgentAccessibility.rowLabel(name: "Clientes", enabled: true, working: true, pauseReason: nil, next: "mañana")
        XCTAssertEqual(label, "Clientes: trabajando")
    }

    func testNormalRow() {
        let label = AgentAccessibility.rowLabel(name: "Contenido", enabled: true, working: false, pauseReason: nil, next: "en 2 horas")
        XCTAssertEqual(label, "Contenido: en 2 horas")
    }

    func testToggleLabel() {
        XCTAssertEqual(AgentAccessibility.toggleLabel(name: "Empleo", enabled: true), "Encendido para Empleo")
        XCTAssertEqual(AgentAccessibility.toggleLabel(name: "Empleo", enabled: false), "Apagado para Empleo")
    }

    func testTelegramLabel() {
        XCTAssertEqual(AgentAccessibility.telegramLabel(ready: true, status: "Conectado"), "Telegram conectado")
        XCTAssertEqual(
            AgentAccessibility.telegramLabel(ready: false, status: "Falta confirmar"),
            "Telegram sin configurar: Falta confirmar"
        )
    }

    func testEngineBusyLabel() {
        XCTAssertEqual(AgentAccessibility.engineBusyLabel(busy: true), "La IA está ocupada")
        XCTAssertEqual(AgentAccessibility.engineBusyLabel(busy: false), "La IA está libre")
    }
}
