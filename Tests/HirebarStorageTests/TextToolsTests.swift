import HirebarDomain
import XCTest

@testable import HirebarStorage

final class TextToolsTests: XCTestCase {
    func testAgeMinutes() {
        XCTAssertEqual(TextTools.ageMinutes("Hace 28 minutos"), 28)
        XCTAssertEqual(TextTools.ageMinutes("hace una hora"), 60)
        XCTAssertEqual(TextTools.ageMinutes("Hace 2 días"), 2880)
        XCTAssertEqual(TextTools.ageMinutes("ayer"), 1440)
        XCTAssertNil(TextTools.ageMinutes("sin fecha"))
    }

    func testNormalizeRemovesAccentsAndKeepsTechNames() {
        XCTAssertEqual(TextTools.normalize("Líder Técnico .NET/C#"), " lider tecnico .net/c# ")
    }

    func testDecodeEntities() {
        XCTAssertEqual(TextTools.decodeEntities("Dise&ntilde;o &amp; API &#233;"), "Diseño & API é")
    }

    func testBatchIsManual() {
        XCTAssertTrue(Batch(mode: .followUp, status: .running, manual: true).isManual)
        XCTAssertFalse(Batch(mode: .freelance, status: .pending).isManual)
    }

    func testLegacyBatchesLoadAndSkipUnknownModes() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-tests-\(UUID().uuidString)")
        setenv("HIREBAR_HOME", home.path, 1)
        defer { unsetenv("HIREBAR_HOME") }
        Paths.ensure()
        let recent = ISO8601DateFormatter().string(from: Date())
        let json = """
        [{"id": "e-20261104-102048", "mode": "empleo", "created": "\(recent)", "items": [], "status": "hecho"},
         {"id": "x-1", "mode": "desconocido", "created": "\(recent)", "items": [], "status": "hecho"}]
        """
        try Data(json.utf8).write(to: BatchStore.url)
        let batches = BatchStore.load()
        XCTAssertEqual(batches.count, 1)
        XCTAssertEqual(batches.first?.mode, .jobs)
        XCTAssertEqual(batches.first?.status, .done)
    }
}
