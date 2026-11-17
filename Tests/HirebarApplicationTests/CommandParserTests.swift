import Foundation
import HirebarDomain
import XCTest

@testable import HirebarApplication

final class CommandParserTests: XCTestCase {
    static let vocabularyFile = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Resources/comandos.json")

    var vocabulary: CommandVocabulary!
    var parser: CommandParser!

    override func setUpWithError() throws {
        vocabulary = try JSONDecoder().decode(CommandVocabulary.self, from: Data(contentsOf: Self.vocabularyFile))
        parser = CommandParser(vocabulary: vocabulary)
    }

    struct Case {
        let text: String
        let kind: CommandKind
        var target: ListTarget = .latest
        var numbers: [Int] = []
        var isButton = false
        var replyTo: Int?
    }

    func testEachTextBecomesExactlyOneCommand() {
        let cases = [
            Case(text: "si", kind: .approve),
            Case(text: "Sí 1 3", kind: .approve, numbers: [1, 3]),
            Case(text: "envia correos 2", kind: .approve, target: .emails, numbers: [2]),
            Case(text: "si correos", kind: .approve, target: .emails),
            Case(text: "no correos", kind: .discard, target: .emails),
            Case(text: "no", kind: .discard),
            Case(text: "si", kind: .approve, target: .reply(42), replyTo: 42),
            Case(text: "si:gs-20261109-120000-ab12", kind: .approve, target: .batch("gs-20261109-120000-ab12"), isButton: true),
            Case(text: "no:b1", kind: .discard, target: .batch("b1"), isButton: true),
            Case(text: "resume:empleo", kind: .resume, target: .batch("empleo"), isButton: true),
            Case(text: "reanudar empleo", kind: .resume),
            Case(text: "keep:empleo", kind: .keepPaused, target: .batch("empleo"), isButton: true),
            Case(text: "autoon:empleo,freelance", kind: .autoSendConfirm, target: .batch("empleo,freelance"), isButton: true),
            Case(text: "auto empleo si", kind: .autoSend),
            Case(text: "estado", kind: .status),
            Case(text: "agentes", kind: .agents),
            Case(text: "agente clientes off", kind: .agentSwitch),
            Case(text: "corre clientes", kind: .runAgent),
            Case(text: "buscar empleo", kind: .search),
            Case(text: "Anota entrevista el jueves", kind: .note),
            Case(text: "post empresa cambia más corto", kind: .post),
            Case(text: "publica empresa", kind: .publish),
            Case(text: "logro bajé costos", kind: .achievement),
            Case(text: "trabajo nuevo en Acme", kind: .jobChange),
            Case(text: "habilidad Go conozco", kind: .skill),
            Case(text: "hv", kind: .regenerateCV),
            Case(text: "qué tal", kind: .help),
            Case(text: "", kind: .help),
        ]
        for item in cases {
            let parsed = parser.parse(CommandInput(text: item.text, isButton: item.isButton, replyTo: item.replyTo))
            XCTAssertEqual(parsed.kind, item.kind, item.text)
            XCTAssertEqual(parsed.target, item.target, item.text)
            XCTAssertEqual(parsed.numbers, item.numbers, item.text)
        }
    }

    func testNoVerbBelongsToTwoCommands() {
        XCTAssertEqual(vocabulary.repeatedVerbs, [])
    }

    func testEveryCommandExceptVoiceAndHelpHasAVerb() {
        let withoutVerbs = CommandKind.allCases.filter { $0 != .voiceNote && $0 != .help && (vocabulary.verbs[$0.rawValue] ?? []).isEmpty }
        XCTAssertEqual(withoutVerbs, [])
        XCTAssertTrue(Set(vocabulary.verbs.keys).isSubset(of: Set(CommandKind.allCases.map(\.rawValue))))
    }

    func testTheRestKeepsTheOriginalTextAfterTheVerb() {
        let parsed = parser.parse(CommandInput(text: "Logro Bajé el costo de AWS 20%"))
        XCTAssertEqual(parsed.rest, "Bajé el costo de AWS 20%")
    }

    func testVoiceNotesEnterThroughTheSameParser() {
        XCTAssertEqual(parser.parse(CommandInput(text: "", hasAudio: true)).kind, .voiceNote)
    }

    func testRepeatedVerbsAreDetected() {
        let broken = CommandVocabulary(schemaVersion: 1, verbs: ["approve": ["si"], "discard": ["si", "no"]], emailNouns: [])
        XCTAssertEqual(broken.repeatedVerbs, ["si"])
    }
}
