import Foundation
import HirebarDomain

public struct AIRunRequest: Sendable {
    public let runId: String
    public let engine: AIEngineSettings
    public let prompt: String
    public let playbook: URL
    public let profile: RunProfile
    public let browser: Bool

    public init(runId: String, engine: AIEngineSettings, prompt: String, playbook: URL, profile: RunProfile, browser: Bool) {
        self.runId = runId
        self.engine = engine
        self.prompt = prompt
        self.playbook = playbook
        self.profile = profile
        self.browser = browser
    }
}

public struct AIRunResult: Sendable {
    public let code: Int32
    public let output: String
    public let authFailed: Bool
    public let restoredFiles: [String]

    public init(code: Int32, output: String, authFailed: Bool, restoredFiles: [String]) {
        self.code = code
        self.output = output
        self.authFailed = authFailed
        self.restoredFiles = restoredFiles
    }
}

public enum AIRunFailure: Error, Equatable {
    case unavailable(message: String, status: String)
    case couldNotOpen(String)
}

@MainActor
public protocol AIRun: AnyObject {
    var isRunning: Bool { get }
    func stop()
}

@MainActor
public protocol AIRunner {
    func start(_ request: AIRunRequest, completion: @escaping @MainActor @Sendable (AIRunResult) -> Void) -> Result<AIRun, AIRunFailure>
    func loginHint(_ kind: AIEngineKind) -> String
}
