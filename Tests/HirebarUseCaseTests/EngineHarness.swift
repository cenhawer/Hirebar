import Foundation
import HirebarDomain
import HirebarStorage

@testable import HirebarApplication

@MainActor
final class EngineHarness {
    nonisolated static let ownerId: Int64 = 7
    let clock: TestClock
    let runner = TestAIRunner()
    let media = TestMediaRenderer()
    let chat: TestChatChannel
    let runState = MemoryRunState()
    let workspace = RecordingWorkspace()
    let stores: Repositories
    let controller: Controller
    private(set) var replies: [String] = []
    var onReply: ((String) -> Void)?

    init(at moment: Date = Date(timeIntervalSince1970: 1_800_000_000), chatConfigured: Bool = false) {
        clock = TestClock(moment)
        chat = TestChatChannel(isConfigured: { chatConfigured })
        stores = .forTests(runState: runState, workspace: workspace)
        controller = .forTests(stores: stores, chat: chat, clock: clock, aiRunner: runner, media: media)
        controller.replies = { [unowned self] text in
            self.replies.append(text)
            self.onReply?(text)
        }
    }

    nonisolated static func date(year: Int = 2026, month: Int = 11, day: Int, hour: Int, minute: Int = 5) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? Date()
    }

    func anchorOwner() {
        var config = stores.config.load()
        config.channelOwner = ChannelOwner(userId: Self.ownerId, chatId: Self.ownerId, name: "Ana")
        stores.config.save(config)
    }

    func onlyEnable(_ kind: AgentKind, tasks: [AgentTask]) {
        for other in AgentKind.allCases {
            stores.agents.update(other) {
                $0.enabled = other == kind
                $0.tasks = other == kind ? tasks : []
            }
        }
    }

    func message(_ text: String, from userId: Int64 = ownerId, audio: VoiceNoteAudio? = nil) -> ChatMessage {
        let sender = ChannelSender(
            userId: userId, chatId: userId, name: "Ana", username: "ana", isPrivateChat: true, sentAt: clock.now(), viaButton: false)
        return ChatMessage(
            chatId: userId, text: text, replyTo: nil, callbackId: nil, sender: sender, audioFileId: audio?.id,
            audioBytes: audio?.bytes, audioSeconds: audio?.seconds)
    }

    func batchMode(of request: AIRunRequest?) -> Mode? {
        request.flatMap { stores.batches.find(id: $0.runId)?.mode }
    }
}

struct VoiceNoteAudio {
    let id: String
    let bytes: Int
    let seconds: Int
}
