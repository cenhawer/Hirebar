import Foundation
import HirebarApplication

extension AIEngineSettings {
    public static func environment(prompt: String, instructions: URL, profile: RunProfile) -> [String: String] {
        let rules = (try? String(contentsOf: instructions, encoding: .utf8)) ?? ""
        let full = rules.isEmpty ? prompt : "\(rules)\n\n---\n\n\(prompt)"
        var writable: [String] = []
        if case .draft(let paths) = profile { writable = paths }
        return [
            "HIREBAR_PROMPT": prompt,
            "HIREBAR_INSTRUCTIONS": instructions.path,
            "HIREBAR_FULL_PROMPT": full,
            "HIREBAR_WORKSPACE": Paths.workspace.path,
            "HIREBAR_PHASE": profile.phase,
            "HIREBAR_WRITABLE_PATHS": writable.joined(separator: ":"),
        ]
    }
}
