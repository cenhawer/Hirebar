import Foundation
import XCTest

final class PlatformTests: XCTestCase {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()

    func testThePackageAndTheBundleRequireMacOS26AndSwift6() throws {
        let package = try String(contentsOf: Self.root.appendingPathComponent("Package.swift"), encoding: .utf8)
        XCTAssertTrue(package.hasPrefix("// swift-tools-version:6."))
        XCTAssertTrue(package.contains("platforms: [.macOS(.v26)]"))
        let info = try String(contentsOf: Self.root.appendingPathComponent("Resources/Info.plist"), encoding: .utf8)
        XCTAssertTrue(info.contains("<key>LSMinimumSystemVersion</key>\n\t<string>26.0</string>"))
    }

    func testTheInterfaceUsesObservationOnly() throws {
        let walker = FileManager.default.enumerator(at: Self.root.appendingPathComponent("Sources"), includingPropertiesForKeys: nil)
        let files = (walker?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for legacy in ["ObservableObject", "@Published", "@ObservedObject", "@StateObject"] {
                XCTAssertFalse(source.contains(legacy), "\(file.lastPathComponent) usa \(legacy)")
            }
        }
    }
}
