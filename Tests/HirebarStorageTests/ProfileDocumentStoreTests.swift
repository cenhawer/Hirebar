import Foundation
import HirebarApplication
import HirebarDomain
import XCTest

@testable import HirebarStorage

final class ProfileDocumentStoreTests: XCTestCase {
    var folder: URL!
    var file: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        file = folder.appendingPathComponent("perfil.json")
        let template = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/inicial/perfil.json")
        try FileManager.default.copyItem(at: template, to: file)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    func root() throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    }

    func testTheTemplateProfileIsReadIntoTheEditor() {
        let document = ProfileDocumentStore.load(from: file)
        XCTAssertEqual(document.person.name, "Nombre Apellido")
        XCTAssertEqual(document.preferences.usdHour, 20)
        XCTAssertEqual(document.experience.first?.company, "Empresa")
        XCTAssertEqual(document.experience.first?.to, "")
        XCTAssertEqual(document.cvVariants.first?.key, "node")
    }

    func testSavingKeepsWhatTheEditorDoesNotShow() throws {
        let before = try root()
        var document = ProfileDocumentStore.load(from: file)
        document.person.name = "Ana Pérez"
        document.preferences.roles = ["Backend Senior", " "]
        document.experience[0].achievements[0].text = "Bajé el tiempo de respuesta a 150 ms."
        document.experience.append(WorkExperience(role: "Líder técnico", company: "Beta", from: "2025-01"))
        document.cvVariants.removeAll { $0.key == "node" }
        try ProfileDocumentStore.save(document, to: file)
        let after = try root()
        let person = try XCTUnwrap(after["person"] as? [String: Any])
        XCTAssertEqual(person["name"] as? String, "Ana Pérez")
        XCTAssertNotNil(person["languages"])
        XCTAssertNotNil(person["education"])
        XCTAssertEqual((after["skills"] as? [Any])?.count, (before["skills"] as? [Any])?.count)
        XCTAssertNotNil(after["projects"])
        XCTAssertNotNil(after["rules"])
        XCTAssertEqual((after["preferences"] as? [String: Any])?["roles"] as? [String], ["Backend Senior"])
        let jobs = try XCTUnwrap(after["experience"] as? [[String: Any]])
        let achievement = try XCTUnwrap((jobs[0]["achievements"] as? [[String: Any]])?.first)
        XCTAssertEqual(achievement["text"] as? String, "Bajé el tiempo de respuesta a 150 ms.")
        XCTAssertEqual(achievement["tech"] as? [String], ["PostgreSQL", "Node.js"])
        XCTAssertTrue(jobs[1]["to"] is NSNull)
        XCTAssertFalse((after["cvVariants"] as? [[String: Any]] ?? []).contains { $0["id"] as? String == "node" })
        XCTAssertEqual(after[WorkspaceSchema.versionKey] as? Int, WorkspaceSchema.current)
        XCTAssertEqual(ProfileDocumentStore.load(from: file).experience.count, 2)
    }

    func testAProfileFromANewerVersionIsNotOverwritten() throws {
        var object = try root()
        object[WorkspaceSchema.versionKey] = 99
        let newer = try JSONSerialization.data(withJSONObject: object)
        try newer.write(to: file)
        XCTAssertThrowsError(try ProfileDocumentStore.save(ProfileDocument(), to: file)) {
            XCTAssertEqual($0 as? ProfileDocumentFailure, .newerVersion)
        }
        XCTAssertEqual(try Data(contentsOf: file), newer)
    }
}
