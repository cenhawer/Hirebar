import Foundation
import HirebarApplication
import HirebarStorage
import HirebarTelegram

@testable import HirebarEngine

extension Controller {
    static func forTests(aiRunner: AIRunner = TestAIRunner(), media: MediaRenderer = TestMediaRenderer()) -> Controller {
        Controller(
            telegram: Telegram(secrets: NoTestSecrets()), stores: .files, clock: TestClock(), aiRunner: aiRunner, media: media,
            resources: .bundled())
    }
}
