import Foundation
import HirebarApplication

private let log = Log(.storage)

public enum WorkspaceSchema {
    public static let current = 1
    public static let versionKey = "schemaVersion"
}

enum VersionedJSON {
    static let formatting: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

    static func version(of data: Data) -> Int {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (object?[WorkspaceSchema.versionKey] as? NSNumber)?.intValue ?? 0
    }

    static func isNewer(_ url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        return version(of: data) > WorkspaceSchema.current
    }

    static func stamped(_ data: Data, listKey: String? = nil) -> Data? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        var root: [String: Any]
        if let list = object as? [Any], let listKey {
            root = [listKey: list]
        } else if let dictionary = object as? [String: Any] {
            root = dictionary
        } else {
            return nil
        }
        root[WorkspaceSchema.versionKey] = WorkspaceSchema.current
        return try? JSONSerialization.data(withJSONObject: root, options: formatting)
    }

    static func list(from data: Data, key: String) -> Data? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        if object is [Any] { return data }
        guard let list = (object as? [String: Any])?[key] as? [Any] else { return nil }
        return try? JSONSerialization.data(withJSONObject: list)
    }

    static func write<Value: Encodable>(_ value: Value, to url: URL, listKey: String? = nil) throws {
        guard !isNewer(url) else {
            log.write("\(url.lastPathComponent) es de una versión más nueva de Hirebar; no se sobrescribe")
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = stamped(try encoder.encode(value), listKey: listKey) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url, options: .atomic)
    }
}
