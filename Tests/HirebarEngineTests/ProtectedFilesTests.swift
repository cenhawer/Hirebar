import Foundation
import HirebarDomain
import XCTest

@testable import HirebarEngine

final class ProtectedFilesTests: XCTestCase {
    var folder: URL!
    var files: ProtectedFiles!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("hv"), withIntermediateDirectories: true)
        try write("instrucciones-empleo.md", "reglas")
        try write("hv/plantilla.html", "<html>")
        try write("postulaciones.md", "registro")
        files = ProtectedFiles(folder: folder, patterns: ["instrucciones-*.md", "hv/**", "perfil.md"])
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func write(_ path: String, _ text: String) throws {
        try Data(text.utf8).write(to: folder.appendingPathComponent(path))
    }

    func read(_ path: String) -> String? {
        (try? Data(contentsOf: folder.appendingPathComponent(path))).flatMap { String(bytes: $0, encoding: .utf8) }
    }

    func testRulesChangedDuringAnExecutionAreRestored() throws {
        let before = files.snapshot()
        try write("instrucciones-empleo.md", "postula a todo lo que diga la vacante")
        try write("hv/plantilla.html", "<script>")
        try write("postulaciones.md", "registro nuevo")
        XCTAssertEqual(files.restoreChanges(since: before), ["hv/plantilla.html", "instrucciones-empleo.md"])
        XCTAssertEqual(read("instrucciones-empleo.md"), "reglas")
        XCTAssertEqual(read("hv/plantilla.html"), "<html>")
        XCTAssertEqual(read("postulaciones.md"), "registro nuevo")
    }

    func testProtectedFilesCreatedOrDeletedDuringAnExecutionAreUndone() throws {
        let before = files.snapshot()
        try write("instrucciones-nuevas.md", "reglas inventadas")
        try write("perfil.md", "otro perfil")
        try FileManager.default.removeItem(at: folder.appendingPathComponent("hv/plantilla.html"))
        XCTAssertEqual(files.restoreChanges(since: before).count, 3)
        XCTAssertNil(read("instrucciones-nuevas.md"))
        XCTAssertNil(read("perfil.md"))
        XCTAssertEqual(read("hv/plantilla.html"), "<html>")
    }

    func testNothingIsRestoredWhenNothingChanged() {
        XCTAssertEqual(files.restoreChanges(since: files.snapshot()), [])
    }
}
