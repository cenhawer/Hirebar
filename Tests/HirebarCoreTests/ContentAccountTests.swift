import HirebarDomain
import XCTest

@testable import HirebarCore

final class ContentAccountTests: XCTestCase {
    func testPartialAccountKeepsDefaults() throws {
        let json = #"{"id": "empresa", "network": "instagram", "name": "Mi Empresa"}"#
        let account = try JSONDecoder().decode(ContentAccount.self, from: Data(json.utf8))
        XCTAssertEqual(account.network, .instagram)
        XCTAssertEqual(account.name, "Mi Empresa")
        XCTAssertTrue(account.enabled)
        XCTAssertEqual(account.palette, PalettePreset.standard.palette)
        XCTAssertEqual(account.title, "Mi Empresa (Instagram)")
    }

    func testSlug() {
        XCTAssertEqual(ContentAccountStore.slug("Andrés Peña"), "andres-pena")
        XCTAssertEqual(ContentAccountStore.slug("  Empresa  "), "empresa")
    }

    func testRunsOnChosenDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Bogota")!
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 9))!
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 9))!
        let account = ContentAccount(id: "personal", days: ["mar", "jue"])
        XCTAssertTrue(account.runs(on: tuesday, calendar: calendar))
        XCTAssertFalse(account.runs(on: wednesday, calendar: calendar))
    }
}
