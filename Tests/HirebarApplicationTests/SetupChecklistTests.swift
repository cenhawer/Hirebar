import Foundation
import XCTest

@testable import HirebarApplication
@testable import HirebarDomain

final class SetupChecklistTests: XCTestCase {
    func facts(
        owner: String = "Ana", engine: Bool = true, channel: Bool = true, agents: Int = 2, voice: Bool = false,
        voicePermission: PermissionState = .undecided, notifications: PermissionState = .allowed
    ) -> SetupFacts {
        SetupFacts(
            ownerName: owner, engineVerified: engine, channelConnected: channel, enabledAgents: agents, usesVoice: voice,
            voiceRecognition: voicePermission, notifications: notifications)
    }

    func testAFreshInstallationNeedsEveryEssentialStepAndOpensTheAssistant() {
        let fresh = facts(owner: Config.placeholderOwnerName, engine: false, channel: false, agents: 0, notifications: .undecided)
        XCTAssertEqual(SetupChecklist.pending(fresh), [.owner, .aiEngine, .channel, .agents, .notifications])
        XCTAssertTrue(SetupChecklist.needsAssistant(fresh, dismissed: false))
        XCTAssertFalse(SetupChecklist.needsAssistant(fresh, dismissed: true))
    }

    func testACompleteSetupHasNothingPending() {
        XCTAssertTrue(SetupChecklist.pending(facts()).isEmpty)
        XCTAssertFalse(SetupChecklist.needsAssistant(facts(), dismissed: false))
    }

    func testVoicePermissionIsOnlyAskedWhenAnAccountMakesVideos() {
        XCTAssertFalse(SetupChecklist.pending(facts(voice: false)).contains(.voice))
        XCTAssertTrue(SetupChecklist.pending(facts(voice: true)).contains(.voice))
        XCTAssertFalse(SetupChecklist.pending(facts(voice: true, voicePermission: .allowed)).contains(.voice))
    }

    func testOnlyMissingEssentialStepsOpenTheAssistant() {
        let optionalOnly = facts(agents: 0, notifications: .undecided)
        XCTAssertFalse(SetupChecklist.pending(optionalOnly).isEmpty)
        XCTAssertFalse(SetupChecklist.needsAssistant(optionalOnly, dismissed: false))
    }

    func testTheEngineCountsAsTestedOnlyForTheKindThatPassed() {
        var config = Config()
        config.aiEngine.kind = .codex
        config.verifiedEngine = .claude
        let stale = SetupFacts(
            config: config, agents: [], accounts: [], channel: .notConfigured, voiceRecognition: .undecided, notifications: .denied)
        XCTAssertFalse(stale.engineVerified)
        config.verifiedEngine = .codex
        let verified = SetupFacts(
            config: config, agents: [], accounts: [], channel: .notConfigured, voiceRecognition: .undecided, notifications: .denied)
        XCTAssertTrue(verified.engineVerified)
    }

    func testTheConnectedChannelAndVideoAccountsAreReadFromTheState() {
        let owner = ChannelOwner(userId: 1, chatId: 1, name: "Ana")
        let facts = SetupFacts(
            config: Config(), agents: [], accounts: [ContentAccount(id: "empresa", video: true)], channel: .connected(owner, bot: "bot"),
            voiceRecognition: .undecided, notifications: .undecided)
        XCTAssertTrue(facts.channelConnected)
        XCTAssertTrue(facts.usesVoice)
    }

    func testSetupProgressSurvivesSavingTheConfiguration() throws {
        var config = Config()
        config.verifiedEngine = .gemini
        config.setupDismissed = true
        let back = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(back.verifiedEngine, .gemini)
        XCTAssertTrue(back.setupDismissed)
        let legacy = try JSONDecoder().decode(Config.self, from: Data("{}".utf8))
        XCTAssertNil(legacy.verifiedEngine)
        XCTAssertFalse(legacy.setupDismissed)
        XCTAssertEqual(legacy.ownerName, Config.placeholderOwnerName)
    }
}
