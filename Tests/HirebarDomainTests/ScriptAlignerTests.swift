import XCTest

@testable import HirebarDomain

final class ScriptAlignerTests: XCTestCase {
    let texts = ["Hola a todos hoy hablamos de la nube", "Tres errores que cuestan dinero", "Guárdalo para después"]
    let pauses = [VoicePause(start: 3.35, end: 3.9), VoicePause(start: 5.7, end: 6.3)]

    var heard: [WordTiming] {
        let spoken = [
            "hola", "eh", "a", "todos", "hoy", "hablamo", "de", "la", "nube", "tres", "errores", "que", "custan", "dinero", "guardalo",
            "para", "despues",
        ]
        var time = 0.2
        return spoken.enumerated().map { index, word in
            if index == 9 || index == 14 { time += 0.6 }
            defer { time += 0.35 }
            return WordTiming(word: word, start: time, end: time + 0.3)
        }
    }

    struct Expected {
        let start: Double
        let end: Double
        let words: Int
        let firstStart: Double
        let lastEnd: Double
    }

    func assertScenes(_ scenes: [ScriptAligner.SceneTiming], _ expected: [Expected], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(scenes.count, expected.count, file: file, line: line)
        for (scene, want) in zip(scenes, expected) {
            XCTAssertEqual(scene.start, want.start, accuracy: 0.0001, file: file, line: line)
            XCTAssertEqual(scene.end, want.end, accuracy: 0.0001, file: file, line: line)
            XCTAssertEqual(scene.words.count, want.words, file: file, line: line)
            XCTAssertEqual(scene.words.first?.start ?? -1, want.firstStart, accuracy: 0.0001, file: file, line: line)
            XCTAssertEqual(scene.words.last?.end ?? -1, want.lastEnd, accuracy: 0.0001, file: file, line: line)
        }
    }

    func testScenesFollowTheWordsSpokenEvenWithFillersAndMispronunciations() {
        assertScenes(
            ScriptAligner.align(texts, heard: heard, pauses: pauses, duration: 8.0),
            [
                Expected(start: 0, end: 3.85, words: 8, firstStart: 0.2, lastEnd: 3.3),
                Expected(start: 3.85, end: 6.25, words: 5, firstStart: 0.1, lastEnd: 1.8),
                Expected(start: 6.25, end: 8.5, words: 3, firstStart: 0.05, lastEnd: 1.05),
            ])
    }

    func testWithoutRecognizedWordsScenesAreCutAtThePauses() {
        let expected = [
            Expected(start: 0, end: 3.85, words: 8, firstStart: 0, lastEnd: 3.35),
            Expected(start: 3.85, end: 6.25, words: 5, firstStart: 0, lastEnd: 1.85),
            Expected(start: 6.25, end: 8.5, words: 3, firstStart: 0, lastEnd: 2.25),
        ]
        assertScenes(ScriptAligner.align(texts, heard: [], pauses: pauses, duration: 8.0), expected)
        assertScenes(ScriptAligner.align(texts, heard: Array(heard.prefix(2)), pauses: pauses, duration: 8.0), expected)
    }

    func testSimilarWordsToleratePrefixesAndOneLetterTypos() {
        XCTAssertTrue(ScriptAligner.similar("hablamos", "hablamo"))
        XCTAssertTrue(ScriptAligner.similar("cuestan", "custan"))
        XCTAssertFalse(ScriptAligner.similar("nube", "nueve"))
        XCTAssertFalse(ScriptAligner.similar("eh", "a"))
    }
}
