import Foundation
import XCTest

final class SourceShapeTests: XCTestCase {
    static let maximumLines = 300
    static let sources = PlatformTests.root.appendingPathComponent("Sources")

    func sourceFiles() -> [URL] {
        let walker = FileManager.default.enumerator(at: Self.sources, includingPropertiesForKeys: nil)
        return (walker?.allObjects as? [URL] ?? []).filter { $0.pathExtension == "swift" }
    }

    func testNoSourceFileIsLongerThanTheLimit() throws {
        let files = sourceFiles()
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let lines = try String(contentsOf: file, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false).count
            XCTAssertLessThanOrEqual(lines, Self.maximumLines, file.lastPathComponent)
        }
    }

    func testPersonFacingTextGoesThroughTheStringCatalog() throws {
        let sinks = try NSRegularExpression(
            pattern: [
                #"(reply|tell|setStatus|askPerson|\.problem|\.failed)\(""#,
                #"(message|problem|messageText|informativeText) = "(?!Hirebar")"#,
                #"addButton\(withTitle: ""#, #"Problem\(message: ""#,
            ].joined(separator: "|"))
        for file in sourceFiles() {
            let source = try String(contentsOf: file, encoding: .utf8)
            for line in source.split(separator: "\n").map(String.init) {
                let range = NSRange(line.startIndex..., in: line)
                XCTAssertNil(sinks.firstMatch(in: line, range: range), "\(file.lastPathComponent): \(line)")
            }
        }
    }

    func testSourceFilesCarryNoComments() throws {
        for file in sourceFiles() {
            let source = try String(contentsOf: file, encoding: .utf8)
            for line in source.split(separator: "\n") where line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                XCTFail("\(file.lastPathComponent): \(line)")
            }
        }
    }
}
