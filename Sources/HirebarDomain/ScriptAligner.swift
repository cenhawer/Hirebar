import Foundation

public struct WordTiming: Sendable {
    public let word: String
    public let start: Double
    public let end: Double

    public init(word: String, start: Double, end: Double) {
        self.word = word
        self.start = start
        self.end = end
    }
}

public struct VoicePause: Sendable {
    public let start: Double
    public let end: Double

    public init(start: Double, end: Double) {
        self.start = start
        self.end = end
    }

    var middle: Double { (start + end) / 2 }
}

public enum ScriptAligner {
    public struct SceneTiming: Sendable {
        public let start: Double
        public let end: Double
        public let words: [WordTiming]
    }

    struct ScriptWord {
        let scene: Int
        let word: String
        let key: String
    }

    static let minimumScene = 0.6
    static let tailAfterVoice = 0.5
    static let cutBeforeWord = 0.08
    static let cutAfterPause = 0.05
    static let pauseSnap = 0.5
    static let wordPadding = 1.5
    static let minimumMatches = 3
    static let matchShare = 4

    public static func normalize(_ text: String) -> String {
        text.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .filter { $0.isLetter || $0.isNumber }
    }

    public static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map { normalize(String($0)) }.filter { !$0.isEmpty }
    }

    public static func align(_ texts: [String], heard: [WordTiming], pauses: [VoicePause], duration: Double) -> [SceneTiming] {
        let script = scriptWords(texts)
        guard !script.isEmpty else { return splitByPauses(texts, pauses: pauses, duration: duration) }
        let matches = matchedWords(script.map(\.key), spoken: heard.map { normalize($0.word) })
        guard matches.compactMap({ $0 }).count >= max(minimumMatches, script.count / matchShare) else {
            return splitByPauses(texts, pauses: pauses, duration: duration)
        }
        let times = wordTimes(script, matches: matches, heard: heard, duration: duration)
        let cuts = sceneCuts(sceneCount: texts.count, script: script, starts: times.starts, pauses: pauses, duration: duration)
        return cuts.indices.map { scene in
            let start = cuts[scene]
            let end = scene + 1 < cuts.count ? cuts[scene + 1] : duration + tailAfterVoice
            let words = script.indices.filter { script[$0].scene == scene }.map { position in
                WordTiming(
                    word: script[position].word, start: max(0, times.starts[position] - start), end: max(0, times.ends[position] - start))
            }
            return SceneTiming(start: start, end: max(start + minimumScene, end), words: words)
        }
    }

    static func scriptWords(_ texts: [String]) -> [ScriptWord] {
        texts.enumerated().flatMap { scene, text in
            text.split(whereSeparator: \.isWhitespace).map(String.init).compactMap { word in
                let key = normalize(word)
                return key.isEmpty ? nil : ScriptWord(scene: scene, word: word, key: key)
            }
        }
    }

    static func matchedWords(_ script: [String], spoken: [String]) -> [Int?] {
        let rows = script.count
        let columns = spoken.count
        var score = Array(repeating: Array(repeating: 0, count: columns + 1), count: rows + 1)
        if columns > 0 {
            for row in 1...rows {
                for column in 1...columns {
                    let same = similar(script[row - 1], spoken[column - 1]) ? score[row - 1][column - 1] + 1 : 0
                    score[row][column] = max(same, score[row - 1][column], score[row][column - 1])
                }
            }
        }
        var matches = [Int?](repeating: nil, count: rows)
        var row = rows
        var column = columns
        while row > 0 && column > 0 {
            if similar(script[row - 1], spoken[column - 1]) && score[row][column] == score[row - 1][column - 1] + 1 {
                matches[row - 1] = column - 1
                row -= 1
                column -= 1
            } else if score[row - 1][column] >= score[row][column - 1] {
                row -= 1
            } else {
                column -= 1
            }
        }
        return matches
    }

    static func wordTimes(
        _ script: [ScriptWord],
        matches: [Int?],
        heard: [WordTiming],
        duration: Double
    ) -> (starts: [Double], ends: [Double]) {
        var starts = [Double](repeating: 0, count: script.count)
        var ends = [Double](repeating: 0, count: script.count)
        var position = 0
        while position < script.count {
            if let spoken = matches[position] {
                starts[position] = heard[spoken].start
                ends[position] = heard[spoken].end
                position += 1
                continue
            }
            var next = position
            while next < script.count && matches[next] == nil { next += 1 }
            let from = position == 0 ? 0 : ends[position - 1]
            let until = next < script.count ? matches[next].map { heard[$0].start } ?? duration : duration
            let weights = (position..<next).map { Double(script[$0].key.count) + wordPadding }
            let total = max(0.001, weights.reduce(0, +))
            var cursor = from
            for (offset, unmatched) in (position..<next).enumerated() {
                let length = max(0, until - from) * weights[offset] / total
                starts[unmatched] = cursor
                ends[unmatched] = cursor + length
                cursor += length
            }
            position = next
        }
        return (starts, ends)
    }

    static func sceneCuts(sceneCount: Int, script: [ScriptWord], starts: [Double], pauses: [VoicePause], duration: Double) -> [Double] {
        var cuts: [Double] = [0]
        for scene in 1..<max(1, sceneCount) {
            guard let first = script.firstIndex(where: { $0.scene == scene }) else {
                cuts.append(min(duration, (cuts.last ?? 0) + 1))
                continue
            }
            var cut = starts[first] - cutBeforeWord
            let nearest = pauses.min { abs($0.end - starts[first]) < abs($1.end - starts[first]) }
            if let nearest, abs(nearest.end - starts[first]) < pauseSnap { cut = nearest.end - cutAfterPause }
            cuts.append(max((cuts.last ?? 0) + minimumScene, cut))
        }
        return cuts
    }

    public static func splitByPauses(_ texts: [String], pauses: [VoicePause], duration: Double) -> [SceneTiming] {
        let counts = texts.map { max(1, tokens($0).count) }
        let total = Double(counts.reduce(0, +))
        var starts: [Double] = [0]
        var used = Set<Int>()
        for index in 1..<max(1, texts.count) {
            let expected = duration * Double(counts[..<index].reduce(0, +)) / total
            let previous = starts.last ?? 0
            let candidates = pauses.indices.filter { !used.contains($0) && pauses[$0].middle > previous + minimumScene }
            let best = candidates.min { abs(pauses[$0].middle - expected) < abs(pauses[$1].middle - expected) }
            if let best, abs(pauses[best].middle - expected) < max(1.5, duration * 0.12) {
                used.insert(best)
                starts.append(max(previous + minimumScene, pauses[best].end - cutAfterPause))
            } else {
                starts.append(max(previous + minimumScene, expected))
            }
        }
        return starts.indices.map { index in
            let start = starts[index]
            let end = index + 1 < starts.count ? starts[index + 1] : duration + tailAfterVoice
            let talking = pauses.first { $0.start > start + 0.3 && $0.start < end }?.start ?? end
            return SceneTiming(start: start, end: end, words: spread(texts[index], over: max(0.5, talking - start)))
        }
    }

    public static func similar(_ first: String, _ second: String) -> Bool {
        if first == second { return true }
        if first.count >= 3 && second.count >= 3 && (first.hasPrefix(second) || second.hasPrefix(first)) { return true }
        guard first.count >= 4, second.count >= 4, abs(first.count - second.count) <= 1 else { return false }
        return distance(Array(first), Array(second)) <= 1 + (max(first.count, second.count) >= 8 ? 1 : 0)
    }

    public static func distance(_ first: [Character], _ second: [Character]) -> Int {
        var previous = Array(0...second.count)
        for (row, left) in first.enumerated() {
            var current = [row + 1] + Array(repeating: 0, count: second.count)
            for (column, right) in second.enumerated() {
                current[column + 1] = min(previous[column + 1] + 1, current[column] + 1, previous[column] + (left == right ? 0 : 1))
            }
            previous = current
        }
        return previous[second.count]
    }

    public static func spread(_ text: String, over seconds: Double) -> [WordTiming] {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let weights = words.map { Double($0.count) + wordPadding }
        let total = weights.reduce(0, +)
        guard total > 0 else { return [] }
        var cursor = 0.0
        return zip(words, weights).map { word, weight in
            let length = seconds * weight / total
            defer { cursor += length }
            return WordTiming(word: word, start: cursor, end: cursor + length)
        }
    }
}
