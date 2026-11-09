import HirebarApplication
import HirebarDomain
import XCTest

@testable import HirebarStorage

final class AgentTests: XCTestCase {
    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Bogota")!
        return calendar
    }()

    func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }

    func testWeeklyReportRunsSundayAndCatchesUpMonday() {
        let task = AgentTask(mode: .weeklyReport, hours: [18], days: ["dom"], windowHours: 30)
        XCTAssertNil(task.dueSlot(at: date(8, 17), calendar: calendar))
        XCTAssertEqual(task.dueSlot(at: date(8, 18, 5), calendar: calendar)?.hour, 18)
        let monday = task.dueSlot(at: date(9, 10), calendar: calendar)
        XCTAssertEqual(monday.map { calendar.component(.weekday, from: $0.day) }, 1)
        XCTAssertNil(task.dueSlot(at: date(10, 10), calendar: calendar))
    }

    func testWorkdaysOnly() {
        let task = AgentTask(mode: .prospecting, hours: [7], days: ["habiles"], windowHours: 12)
        XCTAssertNotNil(task.dueSlot(at: date(4, 9), calendar: calendar))
        XCTAssertNil(task.dueSlot(at: date(7, 9), calendar: calendar))
    }

    func testMultipleHoursPickTheCurrentSlot() {
        let task = AgentTask(mode: .followUp, hours: [10, 16], windowHours: 3)
        XCTAssertEqual(task.dueSlot(at: date(4, 11), calendar: calendar)?.hour, 10)
        XCTAssertEqual(task.dueSlot(at: date(4, 17), calendar: calendar)?.hour, 16)
        XCTAssertNil(task.dueSlot(at: date(4, 14), calendar: calendar))
    }

    func testNextStart() {
        let task = AgentTask(mode: .linkedInDraft, hours: [9], days: ["mar", "jue"])
        let next = task.nextStart(after: date(4, 10), calendar: calendar)
        XCTAssertEqual(next, date(5, 9))
    }

    func testPartialFileKeepsDefaults() throws {
        let json = #"{"id": "clientes", "enabled": false}"#
        let agent = try JSONDecoder().decode(AgentSettings.self, from: Data(json.utf8))
        XCTAssertFalse(agent.enabled)
        XCTAssertEqual(agent.name, "Clientes")
        XCTAssertEqual(agent.tasks.first?.mode, .prospecting)
    }

    func testDefaultsFollowLegacyConfig() {
        var config = Config()
        config.autoJobs = true
        config.autoEmails = true
        XCTAssertTrue(AgentSettings.defaults(for: .jobs, legacy: config.agentDefaults).autoApprove)
        XCTAssertTrue(AgentSettings.defaults(for: .clients, legacy: config.agentDefaults).autoApprove)
        XCTAssertFalse(AgentSettings.defaults(for: .freelance, legacy: config.agentDefaults).autoApprove)
    }

    func testEveryModeHasOneOwner() {
        for mode in Mode.allCases {
            XCTAssertNotNil(AgentKind.allCases.first { $0 == AgentKind.owner(of: mode) })
        }
        XCTAssertEqual(AgentKind.parse("correos"), .clients)
        XCTAssertEqual(AgentKind.parse("Análisis"), .analyst)
    }
}

final class WeeklyStatsTests: XCTestCase {
    func testReadsAgentMetrics() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("metricas-\(UUID().uuidString).json")
        let json = #"{"2026-S45": {"freelance": {"enviadas": 4, "leidas": 2, "respuestas": 0}, "prospeccion": {"enviados_empresas": 1, "enviados_negocios": 20}}}"#
        try Data(json.utf8).write(to: url)
        XCTAssertEqual(WeeklyStats.lines(for: .freelance, week: "2026-S45", source: url), ["4 enviadas", "2 leídas"])
        XCTAssertEqual(WeeklyStats.lines(for: .clients, week: "2026-S45", source: url), ["21 correos"])
        XCTAssertEqual(WeeklyStats.lines(for: .jobs, week: "2026-S45", source: url), ["0 postuladas"])
        XCTAssertEqual(WeeklyStats.lines(for: .content, week: "2026-S45", source: url), [])
    }
}
