import Foundation
import HirebarApplication
import HirebarCore

enum ClaudeCLI {
    static let authFailureHints = [
        "failed to authenticate", "oauth session expired", "please run /login", "invalid api key",
        "not logged in", "please log in", "codex login", "login required", "unauthenticated",
    ]
    static let writeTools = ["Edit", "Write"]

    static func path() -> String? {
        let home = Paths.home.path
        let candidates = [
            "\(home)/.local/bin/claude", "\(home)/.claude/local/claude",
            "/opt/homebrew/bin/claude", "/usr/local/bin/claude",
        ]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) { return found }
        let out = Shell.run("/bin/zsh", ["-lc", "command -v claude"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (out?.hasPrefix("/") ?? false) ? out : nil
    }

    static func arguments(prompt: String, playbook: URL, profile: RunProfile, browser: Bool, settings: EngineProfiles.Claude) -> [String] {
        let phase = settings.phase(profile)
        let useBrowser = browser && !phase.browserTools.isEmpty
        var arguments = ["-p", prompt]
        if useBrowser { arguments.append("--chrome") }
        arguments += ["--permission-mode", phase.permissionMode]
        if phase.restricted { arguments.append("--restricted") }
        arguments += [
            "--tools", phase.tools.joined(separator: ","),
            "--append-system-prompt-file", playbook.path,
            "--output-format", "text",
            "--allowedTools", allowedTools(phase, profile: profile, browser: useBrowser).joined(separator: ","),
        ]
        let denied = deniedReads(settings.personalFiles, phase: phase, profile: profile)
        if !denied.isEmpty { arguments += ["--disallowedTools", denied.joined(separator: ",")] }
        return arguments
    }

    static func allowedTools(_ phase: EngineProfiles.ClaudePhase, profile: RunProfile, browser: Bool) -> [String] {
        var allowed = phase.tools.filter { profile.canAct || !writeTools.contains($0) }
        if case .draft(let paths) = profile {
            allowed += paths.flatMap { path in writeTools.map { "\($0)(\(rule(for: path)))" } }
        }
        if browser { allowed += phase.browserTools }
        return allowed
    }

    static func deniedReads(_ personalFiles: [String], phase: EngineProfiles.ClaudePhase, profile: RunProfile) -> [String] {
        guard phase.denyPersonalFiles else { return [] }
        var writable: [String] = []
        if case .draft(let paths) = profile { writable = paths }
        let writableNames = Set(writable.map(baseName))
        return personalFiles.filter { !writableNames.contains(baseName($0)) }.map { "Read(./\($0))" }
    }

    static func rule(for path: String) -> String {
        path.hasSuffix("/") ? "./\(path)**" : "./\(path)"
    }

    static func baseName(_ path: String) -> String {
        path.replacingOccurrences(of: "/**", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func process(executable: String, arguments: [String], output: URL, errors: URL) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.currentDirectoryURL = Paths.workspace
        process.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = searchPath
        process.environment = env
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = try? FileHandle(forWritingTo: output)
        process.standardError = try? FileHandle(forWritingTo: errors)
        return process
    }

    static var searchPath: String {
        "\(Paths.home.path)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    }

    static func shellProcess(command: String, environment extra: [String: String], output: URL, errors: URL) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.currentDirectoryURL = Paths.workspace
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = searchPath + ":" + (env["PATH"] ?? "")
        for (key, value) in extra { env[key] = value }
        process.environment = env
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = try? FileHandle(forWritingTo: output)
        process.standardError = try? FileHandle(forWritingTo: errors)
        return process
    }

    struct LaunchProblem: Error {
        let message: String
        let status: String
    }

    enum Launch {
        case executable(String, [String])
        case shell(String, [String: String])
    }

    struct LaunchRequest {
        let prompt: String
        let playbook: URL
        let profile: RunProfile
        let browser: Bool
    }

    static let missingClaudeMessage =
        "No encontré Claude Code en el Mac. Instálalo con: curl -fsSL https://claude.ai/install.sh | bash, "
        + "inicia sesión con 'claude' y vuelve a responder si. O elige otra IA en Ajustes → Motor de IA."
    static let missingProfilesMessage =
        "No encontré los perfiles de permisos de la IA dentro de la app. Vuelve a instalarla con scripts/bundle.sh --install."

    static func browserReadingMessage(_ kind: AIEngineKind) -> String {
        "Esta tarea lee con el navegador y con \(kind.title) no puede hacerlo sin poder actuar. "
            + "Corre solo con Claude Code: elígelo en Ajustes → Motor de IA."
    }

    static func launch(
        engine: AIEngineSettings,
        request: LaunchRequest,
        profiles: EngineProfiles,
        claudePath: () -> String? = path
    ) -> Result<Launch, LaunchProblem> {
        let profile = request.profile
        let prompt = request.prompt
        let playbook = request.playbook
        let browser = request.browser
        switch engine.kind {
        case .claude:
            guard let claude = claudePath() else {
                return .failure(LaunchProblem(message: missingClaudeMessage, status: "falta instalar Claude Code"))
            }
            return .success(
                .executable(
                    claude,
                    arguments(
                        prompt: prompt, playbook: playbook, profile: profile, browser: browser,
                        settings: profiles.claude)))
        case .codex, .gemini:
            let commands = engine.kind == .codex ? profiles.codex : profiles.gemini
            if browser && !profile.canAct && !commands.browserInRead {
                return .failure(LaunchProblem(message: browserReadingMessage(engine.kind), status: "esta tarea necesita Claude Code"))
            }
            return .success(
                .shell(
                    commands.command(profile),
                    AIEngineSettings.environment(prompt: prompt, instructions: playbook, profile: profile)))
        case .custom:
            let command = engine.customCommand(for: profile)
            guard !command.isEmpty else {
                let which = profile.canAct ? "de ejecución" : "de lectura"
                return .failure(
                    LaunchProblem(
                        message: "Falta el comando \(which) de tu IA. Escríbelo en Ajustes → Motor de IA.",
                        status: "falta configurar la IA"))
            }
            return .success(.shell(command, AIEngineSettings.environment(prompt: prompt, instructions: playbook, profile: profile)))
        }
    }

    static func makeProcess(engine: AIEngineSettings, request: LaunchRequest, output: URL, errors: URL) -> Result<Process, LaunchProblem> {
        let profiles: EngineProfiles
        do {
            profiles = try EngineProfiles.bundled()
        } catch {
            return .failure(LaunchProblem(message: missingProfilesMessage, status: "faltan los perfiles de la IA"))
        }
        return launch(engine: engine, request: request, profiles: profiles).map {
            switch $0 {
            case .executable(let executable, let arguments):
                return process(executable: executable, arguments: arguments, output: output, errors: errors)
            case .shell(let command, let environment):
                return shellProcess(command: command, environment: environment, output: output, errors: errors)
            }
        }
    }

    static func loginHint(_ kind: AIEngineKind) -> String {
        switch kind {
        case .claude: return "Abre Terminal, escribe claude y luego /login."
        case .codex: return "Abre Terminal y escribe codex login."
        case .gemini: return "Abre Terminal, escribe gemini y vuelve a iniciar sesión."
        case .custom: return "Vuelve a iniciar sesión en tu IA desde la Terminal."
        }
    }

    static func isAuthFailure(_ text: String) -> Bool {
        let lower = text.lowercased()
        return authFailureHints.contains { lower.contains($0) }
    }
}
