import Foundation
import XCTest

@MainActor
final class AdapterBoundaryTests: XCTestCase {
    nonisolated static let sources = EngineProfileTests.repositoryRoot.appendingPathComponent("Sources")
    nonisolated static let adapters = [
        "HirebarStorage", "HirebarTelegram", "HirebarNotifications", "HirebarPortals", "HirebarMedia", "HirebarAI",
    ]

    func testNoAdapterImportsAnotherAdapter() throws {
        for adapter in Self.adapters {
            let folder = Self.sources.appendingPathComponent(adapter)
            let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "swift" }
            XCTAssertFalse(files.isEmpty, adapter)
            for file in files {
                let source = try String(contentsOf: file, encoding: .utf8)
                for other in Self.adapters where other != adapter {
                    XCTAssertFalse(source.contains("import \(other)\n"), "\(adapter)/\(file.lastPathComponent) importa \(other)")
                }
            }
        }
    }

    func testNoOwnSingletonsAreLeft() throws {
        let walker = FileManager.default.enumerator(at: Self.sources, includingPropertiesForKeys: nil)
        let files = (walker?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(source.contains("static let shared"), file.lastPathComponent)
            XCTAssertFalse(source.contains("static var shared"), file.lastPathComponent)
        }
    }
}
