import Foundation
import XCTest

final class DomainPurityTests: XCTestCase {
    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Sources/HirebarDomain")
    static let forbidden = [
        "FileManager", "Process(", "URLSession", "UserDefaults", "Data(contentsOf", ".write(to:", "Log.write", "import AppKit",
        "import SwiftUI", "import HirebarStorage", "import HirebarApplication",
    ]

    func testTheDomainDoesNoInputOrOutput() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for api in Self.forbidden {
                XCTAssertFalse(source.contains(api), "\(file.lastPathComponent) usa \(api)")
            }
        }
    }
}
