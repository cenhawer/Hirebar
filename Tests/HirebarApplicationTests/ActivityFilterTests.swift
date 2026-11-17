import Foundation
import XCTest

@testable import HirebarApplication
@testable import HirebarDomain

final class ActivityFilterTests: XCTestCase {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Bogota") ?? .current
        return calendar
    }()
    lazy var now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 15)) ?? Date()

    func entry(_ agent: String, daysAgo: Int) -> ActivityEntry {
        ActivityEntry(
            agent: AgentID(rawValue: agent), batch: "b\(daysAgo)", action: .apply, target: .url("https://acme.co/\(daysAgo)"),
            text: nil, at: now.addingTimeInterval(-Double(daysAgo) * 86400), outcome: .sent)
    }

    func testEntriesAreFilteredByAgentAndPeriodNewestFirst() {
        let entries = [
            entry("empleo", daysAgo: 10), entry("freelance", daysAgo: 0), entry("empleo", daysAgo: 2), entry("empleo", daysAgo: 0),
        ]
        let week = ActivityFilter(agent: AgentID(rawValue: "empleo"), period: .week).apply(entries, now: now, calendar: calendar)
        XCTAssertEqual(week.map(\.batch), ["b0", "b2"])
        let today = ActivityFilter(period: .today).apply(entries, now: now, calendar: calendar)
        XCTAssertEqual(Set(today.map(\.agent.rawValue)), ["empleo", "freelance"])
        XCTAssertEqual(ActivityFilter(period: .all).apply(entries, now: now, calendar: calendar).first?.at, now)
        XCTAssertEqual(ActivityFilter(period: .month).apply(entries, now: now, calendar: calendar).count, 4)
    }
}
