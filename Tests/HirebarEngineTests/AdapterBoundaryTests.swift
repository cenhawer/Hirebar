import Foundation
import XCTest

final class AdapterBoundaryTests: XCTestCase {
    static let sources = EngineProfileTests.repositoryRoot.appendingPathComponent("Sources")
    static let adapters = ["HirebarStorage", "HirebarTelegram", "HirebarNotifications", "HirebarPortals", "HirebarMedia", "HirebarAI"]

    func testNoAdapterImportsAnotherAdapterOrTheEngine() throws {
        for adapter in Self.adapters {
            let folder = Self.sources.appendingPathComponent(adapter)
            let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "swift" }
            XCTAssertFalse(files.isEmpty, adapter)
            for file in files {
                let source = try String(contentsOf: file, encoding: .utf8)
                for other in Self.adapters + ["HirebarEngine"] where other != adapter {
                    XCTAssertFalse(source.contains("import \(other)\n"), "\(adapter)/\(file.lastPathComponent) importa \(other)")
                }
            }
        }
    }
}
