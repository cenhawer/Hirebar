import Foundation
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

public enum ProfileRequests {
    public static let fileName = "perfil-cambios.txt"
    static var url: URL { Paths.workspaceFile(fileName) }

    public static func append(_ kind: String, _ text: String) {
        Paths.ensure()
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "- \(stamp) · \(kind): \(text)\n"
        let previous = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? (previous + line).write(to: url, atomically: true, encoding: .utf8)
    }

    public static func clear() {
        try? "".write(to: url, atomically: true, encoding: .utf8)
    }
}
