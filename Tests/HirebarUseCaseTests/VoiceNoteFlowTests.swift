import Foundation
import HirebarDomain
import XCTest

@testable import HirebarApplication

@MainActor
final class VoiceNoteFlowTests: XCTestCase {
    nonisolated static let home = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-voice-\(UUID().uuidString)")
    let account = ContentAccount(id: "empresa", video: true)
    var harness: EngineHarness!

    override static func setUp() {
        setenv("HIREBAR_HOME", home.path, 1)
    }

    override static func tearDown() {
        try? FileManager.default.removeItem(at: home)
    }

    override func setUp() async throws {
        harness = EngineHarness(chatConfigured: true)
        harness.anchorOwner()
        try? FileManager.default.removeItem(at: account.folder)
        try harness.stores.contentAccounts.save([account])
    }

    func prepareScenes() throws {
        try FileManager.default.createDirectory(at: account.videoFolder, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: account.videoScript)
    }

    func voiceNote(seconds: Int = 20) -> ChatMessage {
        harness.message("", audio: VoiceNoteAudio(id: "voz-1", bytes: 50_000, seconds: seconds))
    }

    func expectReply(containing text: String) -> XCTestExpectation {
        let arrived = expectation(description: text)
        harness.onReply = { reply in
            if reply.contains(text) { arrived.fulfill() }
        }
        return arrived
    }

    func testAVoiceNoteBecomesTheNarratedVideoAndAsksToPublish() async throws {
        try prepareScenes()
        let video = Self.home.appendingPathComponent("reel.mp4")
        harness.chat.downloads = true
        harness.media.voicedVideo = video
        let asked = expectReply(containing: "¿Lo subo?")
        harness.controller.handle(voiceNote())
        await fulfillment(of: [asked], timeout: 2)
        XCTAssertEqual(harness.chat.videos, [video])
        XCTAssertEqual(harness.chat.downloadRequests, 1)
    }

    func testAFailedDownloadAsksToSendItAgain() async throws {
        try prepareScenes()
        let retry = expectReply(containing: "No pude descargar")
        harness.controller.handle(voiceNote())
        await fulfillment(of: [retry], timeout: 2)
        XCTAssertTrue(harness.chat.videos.isEmpty)
    }

    func testWithoutAVideoWaitingTheNoteExplainsWhatToDo() {
        harness.controller.handle(voiceNote())
        XCTAssertTrue(harness.replies.last?.contains("no tengo ningún video esperando voz") == true)
        XCTAssertEqual(harness.chat.downloadRequests, 0)
    }

    func testATooLongVoiceNoteIsRejectedBeforeDownloading() throws {
        try prepareScenes()
        harness.media.audio = .tooLong(minutes: 5, megabytes: 20)
        harness.controller.handle(voiceNote(seconds: 900))
        XCTAssertTrue(harness.replies.last?.contains("muy largo") == true)
        XCTAssertEqual(harness.chat.downloadRequests, 0)
    }
}
