import Foundation
import HirebarCore
import HirebarDomain

public enum EngineCheck {
    static let timeout: TimeInterval = 180

    public static func run(_ engine: AIEngineSettings, completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            Paths.ensure()
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-check", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let rules = folder.appendingPathComponent("instrucciones.md")
            let output = folder.appendingPathComponent("salida.txt")
            let errors = folder.appendingPathComponent("errores.txt")
            try? "Responde únicamente con la palabra OK, sin nada más.".write(to: rules, atomically: true, encoding: .utf8)
            FileManager.default.createFile(atPath: output.path, contents: nil)
            FileManager.default.createFile(atPath: errors.path, contents: nil)
            let request = ClaudeCLI.LaunchRequest(prompt: "Responde solo: OK", playbook: rules, profile: .read, browser: false)
            let launch = ClaudeCLI.makeProcess(engine: engine, request: request, output: output, errors: errors)
            guard case .success(let process) = launch else {
                if case .failure(let problem) = launch { finish(false, problem.message, completion) }
                return
            }
            do {
                try process.run()
            } catch {
                finish(false, "No se pudo abrir: \(error.localizedDescription)", completion)
                return
            }
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.5) }
            if process.isRunning {
                process.terminate()
                finish(false, "No respondió en \(Int(timeout)) segundos.", completion)
                return
            }
            let out = ((try? String(contentsOf: output, encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let err = ((try? String(contentsOf: errors, encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if process.terminationStatus == 0 && out.uppercased().contains("OK") {
                finish(true, "Funciona: \(engine.kind.title) respondió.", completion)
            } else if ClaudeCLI.isAuthFailure(out + "\n" + err) {
                finish(false, "Falta iniciar sesión. \(ClaudeCLI.loginHint(engine.kind))", completion)
            } else {
                let detail = String((err.isEmpty ? out : err).suffix(300))
                finish(false, "Falló (código \(process.terminationStatus)): \(detail.isEmpty ? "sin salida" : detail)", completion)
            }
        }
    }

    private static func finish(_ ok: Bool, _ message: String, _ completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.main.async { completion(ok, message) }
    }
}
