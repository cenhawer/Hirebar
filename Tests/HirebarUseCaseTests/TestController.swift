import Foundation
import HirebarStorage
import HirebarTelegram

@testable import HirebarApplication

extension Controller {
    static func forTests(aiRunner: AIRunner = TestAIRunner(), media: MediaRenderer = TestMediaRenderer()) -> Controller {
        let adapters = EngineAdapters(
            chat: TestChatChannel(), desktop: TestDesktopNotifications(), clock: TestClock(), aiRunner: aiRunner, media: media,
            resources: .bundled())
        return Controller(stores: .files, adapters: adapters)
    }
}
