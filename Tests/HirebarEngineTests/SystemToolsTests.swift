import Foundation
import XCTest

@testable import HirebarEngine

final class SystemToolsTests: XCTestCase {
    var tools: SystemTools!

    override func setUpWithError() throws {
        tools = try SystemTools.load(from: EngineProfileTests.repositoryRoot.appendingPathComponent("Resources/herramientas.json"))
    }

    func testFfmpegComesOnlyFromTheSystemPaths() {
        XCTAssertEqual(tools.ffmpegPath { $0 == "/usr/local/bin/ffmpeg" }, "/usr/local/bin/ffmpeg")
        XCTAssertNil(tools.ffmpegPath { _ in false })
        XCTAssertTrue(tools.ffmpeg.install.contains("brew install ffmpeg"))
    }

    func testAudiosOverTheSizeOrDurationLimitAreRejected() {
        XCTAssertTrue(tools.acceptsAudio(bytes: 1_000_000, seconds: 60))
        XCTAssertTrue(tools.acceptsAudio(bytes: nil, seconds: nil))
        XCTAssertFalse(tools.acceptsAudio(bytes: tools.maxAudioBytes + 1, seconds: 60))
        XCTAssertFalse(tools.acceptsAudio(bytes: 1_000, seconds: tools.maxAudioSeconds + 1))
    }

    func testNoToolIsInstalledWithPythonOrPip() throws {
        let source = try String(
            contentsOf: EngineProfileTests.repositoryRoot.appendingPathComponent("Sources/HirebarEngine/AudioTools.swift"), encoding: .utf8)
        XCTAssertFalse(source.contains("pip"))
        XCTAssertFalse(source.contains("venv"))
    }
}
