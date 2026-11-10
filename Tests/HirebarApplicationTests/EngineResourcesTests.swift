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

    static let repositoryPolicy = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Resources/motor.json")

    func policyData(_ change: (inout [String: Any]) -> Void) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: Self.repositoryPolicy)) as? [String: Any])
        change(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }

    func testTheBundledEnginePolicyIsReadable() throws {
        let policy = try EnginePolicy.decode(Data(contentsOf: Self.repositoryPolicy))
        XCTAssertEqual(policy.corridas.maximum, 3600)
        XCTAssertEqual(policy.radares.freelance.seenWindow, 14 * 86400)
        XCTAssertEqual(policy.programador.horaLimpiezaDomingo, 19)
    }

    func testAnEnginePolicyWithAnUnknownVersionOrEmptyLimitsIsRejected() throws {
        let newer = try policyData { $0["schemaVersion"] = 2 }
        XCTAssertThrowsError(try EnginePolicy.decode(newer)) { XCTAssertEqual($0 as? ResourceFailure, .unsupportedVersion(2)) }
        let empty = try policyData { object in
            var runs = object["corridas"] as? [String: Any] ?? [:]
            runs["maximoMinutos"] = 0
            object["corridas"] = runs
        }
        XCTAssertThrowsError(try EnginePolicy.decode(empty)) { XCTAssertEqual($0 as? ResourceFailure, .invalidValues) }
    }
}
