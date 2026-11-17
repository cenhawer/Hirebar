import AppKit
import HirebarApplication
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

enum LogExport {
    nonisolated static let tool = "/usr/bin/log"
    nonisolated static let window = "3d"

    static func openRecent() {
        let file = Paths.log
        DispatchQueue.global(qos: .userInitiated).async {
            try? FileManager.default.createDirectory(at: Paths.logs, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: file.path, contents: nil)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = ["show", "--predicate", "subsystem == \"\(Log.subsystem)\"", "--last", window, "--style", "compact"]
            process.standardOutput = try? FileHandle(forWritingTo: file)
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
            DispatchQueue.main.async { NSWorkspace.shared.open(file) }
        }
    }
}
