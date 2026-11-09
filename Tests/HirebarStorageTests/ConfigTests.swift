import HirebarApplication
import HirebarDomain
import XCTest

@testable import HirebarStorage

final class ConfigTests: XCTestCase {
    func testReadsLegacyRadarConfig() throws {
        let legacy = """
            {"autoCorreos": true, "autoFreelance": true, "autoJobs": false, "chatId": 42, "computrabajo": false,
             "freelanceMinutes": 20, "linkedin": true, "topic": "old-topic", "workana": true}
            """
        let config = try JSONDecoder().decode(Config.self, from: Data(legacy.utf8))
        XCTAssertTrue(config.autoEmails)
        XCTAssertTrue(config.autoFreelance)
        XCTAssertFalse(config.autoJobs)
        XCTAssertEqual(config.channelOwner, ChannelOwner(userId: 42, chatId: 42, name: ""))
        XCTAssertFalse(String(bytes: try JSONEncoder().encode(config), encoding: .utf8)?.contains("old-topic") ?? true)
        XCTAssertFalse(config.isEnabled("computrabajo"))
        XCTAssertTrue(config.isEnabled("linkedin"))
        XCTAssertTrue(config.isEnabled("magneto"))
    }

    func testRoundTripKeepsSources() throws {
        var config = Config()
        config.setEnabled("magneto", false)
        config.ownerName = "Ana"
        let data = try JSONEncoder().encode(config)
        let back = try JSONDecoder().decode(Config.self, from: data)
        XCTAssertFalse(back.isEnabled("magneto"))
        XCTAssertEqual(back.ownerName, "Ana")
        XCTAssertTrue(back.jobsOn)
    }

    func testMinimumIntervals() throws {
        let config = try JSONDecoder().decode(Config.self, from: Data(#"{"freelanceMinutes": 1, "jobMinutes": 5}"#.utf8))
        XCTAssertEqual(config.freelanceMinutes, 15)
        XCTAssertEqual(config.jobMinutes, 20)
    }

    func testLinkedGroupChatIsNotAnchoredToAnyone() throws {
        let config = try JSONDecoder().decode(Config.self, from: Data(#"{"chatId": -1001234}"#.utf8))
        XCTAssertNil(config.channelOwner)
        XCTAssertEqual(config.chatId, 0)
    }

    func testChannelOwnerRoundTrips() throws {
        var config = Config()
        config.channelOwner = ChannelOwner(userId: 7, chatId: 7, name: "Ana", username: "ana")
        let back = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(back.channelOwner, config.channelOwner)
        XCTAssertEqual(back.chatId, 7)
    }
}
