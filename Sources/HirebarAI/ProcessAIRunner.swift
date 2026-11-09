import Foundation
import HirebarApplication
import HirebarDomain

public struct ProcessAIRunner: AIRunner {
    public init() {}

    public func start(_ request: AIRunRequest, completion: @escaping (AIRunResult) -> Void) -> Result<AIRun, AIRunFailure> {
        try? FileManager.default.createDirectory(at: Paths.runs, withIntermediateDirectories: true)
        let output = Paths.runs.appendingPathComponent("\(request.runId).txt")
        let errors = Paths.runs.appendingPathComponent("\(request.runId).log")
        FileManager.default.createFile(atPath: output.path, contents: nil)
        FileManager.default.createFile(atPath: errors.path, contents: nil)
        let launch = ClaudeCLI.LaunchRequest(
            prompt: request.prompt, playbook: request.playbook, profile: request.profile, browser: request.browser)
        let process: Process
        switch ClaudeCLI.makeProcess(engine: request.engine, request: launch, output: output, errors: errors) {
        case .failure(let problem): return .failure(.unavailable(message: problem.message, status: problem.status))
        case .success(let made): process = made
        }
        let protected = request.profile.canAct ? Self.protectedFiles() : nil
        let snapshot = protected?.snapshot()
        process.terminationHandler = { finished in
            let code = finished.terminationStatus
            let restored = snapshot.flatMap { protected?.restoreChanges(since: $0) } ?? []
            let text = ((try? String(contentsOf: output, encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let problems = (try? String(contentsOf: errors, encoding: .utf8)) ?? ""
            let result = AIRunResult(
                code: code, output: text, authFailed: code != 0 && ClaudeCLI.isAuthFailure(text + "\n" + problems),
                restoredFiles: restored)
            DispatchQueue.main.async { completion(result) }
        }
        do {
            try process.run()
        } catch {
            return .failure(.couldNotOpen(error.localizedDescription))
        }
        return .success(ProcessRun(process: process))
    }

    static func protectedFiles() -> ProtectedFiles? {
        (try? EngineProfiles.bundled()).map { ProtectedFiles(folder: Paths.workspace, patterns: $0.restoredFiles) }
    }
}

final class ProcessRun: AIRun {
    let process: Process

    init(process: Process) {
        self.process = process
    }

    var isRunning: Bool { process.isRunning }

    func stop() {
        process.terminate()
    }
}
