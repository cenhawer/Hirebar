import Foundation
import HirebarDomain

public enum Log {
    private static let queue = DispatchQueue(label: "hirebar.log")

    public static func write(_ text: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(text)\n"
        queue.async {
            let url = Paths.log
            let fm = FileManager.default
            if !fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(at: Paths.logs, withIntermediateDirectories: true)
                fm.createFile(atPath: url.path, contents: nil)
            }
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            }
        }
    }
}
