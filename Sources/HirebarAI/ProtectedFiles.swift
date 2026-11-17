import Foundation
import HirebarDomain

public struct ProtectedFiles: Sendable {
    public typealias Snapshot = [String: Data]

    public let folder: URL
    public let patterns: [String]

    public init(folder: URL, patterns: [String]) {
        self.folder = folder
        self.patterns = patterns
    }

    public func snapshot() -> Snapshot {
        var contents: Snapshot = [:]
        for path in matchingPaths() {
            contents[path] = try? Data(contentsOf: folder.appendingPathComponent(path))
        }
        return contents
    }

    public func restoreChanges(since before: Snapshot) -> [String] {
        let now = snapshot()
        var restored: [String] = []
        for path in Set(before.keys).union(now.keys).sorted() where before[path] != now[path] {
            let file = folder.appendingPathComponent(path)
            if let original = before[path] {
                try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? original.write(to: file, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: file)
            }
            restored.append(path)
        }
        return restored
    }

    public func matchingPaths() -> [String] {
        patterns.flatMap { pattern -> [String] in
            if pattern.hasSuffix("/**") {
                return filesBelow(String(pattern.dropLast(3)))
            }
            guard let star = pattern.firstIndex(of: "*") else {
                return FileManager.default.fileExists(atPath: folder.appendingPathComponent(pattern).path) ? [pattern] : []
            }
            let prefix = String(pattern[..<star])
            let suffix = String(pattern[pattern.index(after: star)...])
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            return names.filter { $0.hasPrefix(prefix) && $0.hasSuffix(suffix) && $0.count >= prefix.count + suffix.count }
        }
    }

    public func filesBelow(_ directory: String) -> [String] {
        let root = folder.appendingPathComponent(directory, isDirectory: true)
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        return walker.compactMap { $0 as? URL }
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .map { directory + "/" + $0.resolvingSymlinksInPath().path.dropFirst(root.resolvingSymlinksInPath().path.count + 1) }
    }
}
