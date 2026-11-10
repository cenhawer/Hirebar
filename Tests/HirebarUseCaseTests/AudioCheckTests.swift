import Foundation
import HirebarStorage
import HirebarTelegram
import XCTest

@testable import HirebarApplication

final class AudioCheckTests: XCTestCase {
    var media: TestMediaRenderer!
    var controller: Controller!

    override func setUp() {
        media = TestMediaRenderer()
        controller = Controller.forTests(media: media)
    }

    func testAnAcceptedVoiceNoteHasNoProblem() {
        XCTAssertNil(controller.audioProblem(bytes: 1000, seconds: 30))
    }

    func testMissingFfmpegTellsTheCommandToInstallIt() {
        media.audio = .ffmpegMissing(install: "brew install ffmpeg")
        XCTAssertTrue(controller.audioProblem(bytes: nil, seconds: nil)?.contains("brew install ffmpeg") == true)
    }

    func testATooLongVoiceNoteStatesTheLimits() {
        media.audio = .tooLong(minutes: 5, megabytes: 20)
        let problem = controller.audioProblem(bytes: nil, seconds: 900) ?? ""
        XCTAssertTrue(problem.contains("5 minutos"))
        XCTAssertTrue(problem.contains("20 MB"))
    }
}
