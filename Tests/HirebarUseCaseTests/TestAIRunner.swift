import Foundation
import HirebarApplication

final class TestAIRunner: AIRunner {
    final class Run: AIRun {
        var isRunning = true
        func stop() { isRunning = false }
    }

    var failure: AIRunFailure?
    private(set) var requests: [AIRunRequest] = []
    private(set) var completions: [@MainActor @Sendable (AIRunResult) -> Void] = []

    func start(_ request: AIRunRequest, completion: @escaping @MainActor @Sendable (AIRunResult) -> Void) -> Result<AIRun, AIRunFailure> {
        requests.append(request)
        if let failure { return .failure(failure) }
        completions.append(completion)
        return .success(Run())
    }

    func loginHint(_ kind: AIEngineKind) -> String { "" }

    func finish(_ result: AIRunResult) {
        guard !completions.isEmpty else { return }
        completions.removeFirst()(result)
    }
}
