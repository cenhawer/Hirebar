import Foundation
import HirebarDomain
import XCTest

@testable import HirebarApplication

final class ApplicationPurityTests: XCTestCase {
    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Sources/HirebarApplication")
    static let forbidden = [
        "FileManager", "Process(", "URLSession", "UserDefaults", "Data(contentsOf", ".write(to:", "import AppKit", "import SwiftUI",
        "import HirebarCore",
    ]

    func testTheApplicationLayerDoesNoInputOrOutput() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for api in Self.forbidden {
                XCTAssertFalse(source.contains(api), "\(file.lastPathComponent) usa \(api)")
            }
        }
    }

    func testEachAgentAndAreaLogsUnderItsOwnCategory() {
        let categories = AgentKind.allCases.map(\.rawValue) + Log.Area.allCases.map(\.rawValue)
        XCTAssertEqual(Set(categories).count, categories.count)
        XCTAssertEqual(Log.subsystem, "com.vmsoftware.hirebar")
    }
}
