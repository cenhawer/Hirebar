import Foundation
import XCTest

@testable import HirebarApplication

final class EngineResourcesTests: XCTestCase {
    func testChannelSettingsRejectAnUnknownVersionAndEmptyLimits() {
        let newer = Data(#"{"schemaVersion": 2, "pairingMinutes": 10, "messagesPerMinute": 20}"#.utf8)
        XCTAssertThrowsError(try ChannelSettings.decode(newer)) { XCTAssertEqual($0 as? ResourceFailure, .unsupportedVersion(2)) }
        let empty = Data(#"{"schemaVersion": 1, "pairingMinutes": 0, "messagesPerMinute": 20}"#.utf8)
        XCTAssertThrowsError(try ChannelSettings.decode(empty)) { XCTAssertEqual($0 as? ResourceFailure, .invalidValues) }
        let valid = Data(#"{"schemaVersion": 1, "pairingMinutes": 10, "messagesPerMinute": 20}"#.utf8)
        XCTAssertEqual(try ChannelSettings.decode(valid).pairingWindow, 600)
    }

    func testAVerbUsedByTwoCommandsIsRejected() {
        let repeated = Data(#"{"schemaVersion": 1, "verbs": {"approve": ["si"], "discard": ["si"]}, "emailNouns": []}"#.utf8)
        XCTAssertThrowsError(try CommandVocabularyFile.decode(repeated)) {
            XCTAssertEqual($0 as? ResourceFailure, .repeatedVerbs(["si"]))
        }
    }

    func testTargetRulesIgnoreTheConfiguredTrackingParameters() throws {
        let data = Data(
            #"{"schemaVersion": 1, "webSchemes": ["https"], "ignoredQueryParameters": ["TRK"], "ignoredQueryParameterPrefixes": ["utm_"]}"#
                .utf8)
        let rules = try TargetRulesFile.decode(data)
        XCTAssertEqual(rules.ignoredQueryParameters, ["trk"])
        XCTAssertEqual(rules.ignoredQueryParameterPrefixes, ["utm_"])
        XCTAssertEqual(rules.webSchemes, ["https"])
    }
}
