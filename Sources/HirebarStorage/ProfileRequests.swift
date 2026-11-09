import Foundation
import HirebarApplication

enum ProfileRequests {
    static let fileName = "perfil-cambios.txt"
    static var url: URL { Paths.workspaceFile(fileName) }

    static func append(_ kind: String, _ text: String, at date: Date) {
        Paths.ensure()
        let stamp = ISO8601DateFormatter().string(from: date)
        let line = "- \(stamp) · \(kind): \(text)\n"
        try? (read(raw: true) + line).write(to: url, atomically: true, encoding: .utf8)
    }

    static func read(raw: Bool = false) -> String {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return raw ? text : text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func clear() {
        try? "".write(to: url, atomically: true, encoding: .utf8)
    }
}
