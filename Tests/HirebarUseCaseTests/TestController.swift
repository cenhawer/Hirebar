import Foundation
import HirebarDomain
import HirebarStorage

@testable import HirebarApplication

@MainActor
extension Controller {
    nonisolated static var repositoryPolicy: EnginePolicy {
        let file = EngineProfileTests.repositoryRoot.appendingPathComponent("Resources/motor.json")
        guard let policy = try? EnginePolicy.load(from: file) else { fatalError("Resources/motor.json no se pudo leer") }
        return policy
    }

    nonisolated static var repositorySearchDefaults: SearchProfile {
        let file = EngineProfileTests.repositoryRoot.appendingPathComponent("Resources/perfil-busqueda.json")
        guard let defaults = try? SearchProfile.loadDefaults(from: file) else {
            fatalError("Resources/perfil-busqueda.json no se pudo leer")
        }
        return defaults
    }

    nonisolated static var repositoryResources: EngineResources {
        let folder = EngineProfileTests.repositoryRoot.appendingPathComponent("Resources")
        return EngineResources(
            targetRules: (try? TargetRulesFile.load(from: folder.appendingPathComponent("destinos.json"))) ?? TargetRulesFile.fallback,
            commands: try? CommandVocabularyFile.load(from: folder.appendingPathComponent("comandos.json")),
            channel: try? ChannelSettings.load(from: folder.appendingPathComponent("canal.json")), policy: repositoryPolicy,
            searchDefaults: repositorySearchDefaults)
    }

    static func forTests(
        stores: Repositories = .forTests(), chat: ChatChannel = TestChatChannel(), clock: Clock = TestClock(),
        aiRunner: AIRunner = TestAIRunner(), media: MediaRenderer = TestMediaRenderer()
    ) -> Controller {
        let adapters = EngineAdapters(
            chat: chat, desktop: TestDesktopNotifications(), clock: clock, aiRunner: aiRunner, media: media,
            resources: repositoryResources)
        return Controller(stores: stores, adapters: adapters)
    }
}
