import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import XCTest

@testable import HirebarEngine

final class NotifierTests: XCTestCase {
    func testLongAnnouncementsAreSplitWithoutLosingAnyItem() {
        let blocks = ["Título", String(repeating: "a", count: 30), String(repeating: "b", count: 30), "Pie"]
        let messages = Notifier.chunks(blocks, limit: 40)
        XCTAssertTrue(messages.allSatisfy { $0.count <= 40 })
        XCTAssertEqual(messages.joined(separator: "\n\n").replacingOccurrences(of: "\n\n", with: ""), blocks.joined())
    }

    func testABlockLongerThanTheLimitIsCutIntoPieces() {
        let messages = Notifier.chunks([String(repeating: "x", count: 95)], limit: 40)
        XCTAssertEqual(messages.map(\.count), [40, 40, 15])
    }

    func testShortAnnouncementsStayInOneMessage() {
        XCTAssertEqual(Notifier.chunks(["Título", "1. uno", "Pie"], limit: 100), ["Título\n\n1. uno\n\nPie"])
    }
}
