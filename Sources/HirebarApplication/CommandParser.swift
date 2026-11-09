import Foundation

public enum CommandKind: String, CaseIterable, Codable, Sendable {
    case approve
    case discard
    case status
    case resume
    case keepPaused
    case followUps
    case weeklyReport
    case note
    case autoSendConfirm
    case autoSendCancel
    case autoSend
    case agents
    case agentSwitch
    case runAgent
    case publish
    case post
    case video
    case remake
    case achievement
    case jobChange
    case skill
    case skills
    case regenerateCV
    case search
    case voiceNote
    case help
}

public enum ListTarget: Equatable, Sendable {
    case latest
    case emails
    case batch(String)
    case reply(Int)
}

public struct CommandVocabulary: Decodable, Equatable, Sendable {
    public let schemaVersion: Int
    public let verbs: [String: [String]]
    public let emailNouns: [String]

    public init(schemaVersion: Int, verbs: [String: [String]], emailNouns: [String]) {
        self.schemaVersion = schemaVersion
        self.verbs = verbs
        self.emailNouns = emailNouns
    }

    public var repeatedVerbs: [String] {
        Dictionary(grouping: verbs.values.flatMap { $0 }, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
    }

    func kind(of verb: String) -> CommandKind? {
        verbs.first { $0.value.contains(verb) }.flatMap { CommandKind(rawValue: $0.key) }
    }
}

public struct CommandInput: Equatable, Sendable {
    public let text: String
    public let isButton: Bool
    public let replyTo: Int?
    public let hasAudio: Bool

    public init(text: String, isButton: Bool = false, replyTo: Int? = nil, hasAudio: Bool = false) {
        self.text = text
        self.isButton = isButton
        self.replyTo = replyTo
        self.hasAudio = hasAudio
    }
}

public struct ParsedCommand: Equatable, Sendable {
    public let kind: CommandKind
    public let target: ListTarget
    public let numbers: [Int]
    public let words: [String]
    public let rest: String
    public let argument: String?
}

public struct CommandParser: Sendable {
    let vocabulary: CommandVocabulary
    static let buttonSeparator: Character = ":"

    public init(vocabulary: CommandVocabulary) {
        self.vocabulary = vocabulary
    }

    public static func normalize(_ text: String) -> String {
        text.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func parse(_ input: CommandInput) -> ParsedCommand {
        let original = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.hasAudio {
            return ParsedCommand(kind: .voiceNote, target: .latest, numbers: [], words: [], rest: original, argument: nil)
        }
        var text = Self.normalize(original)
        var argument: String?
        if input.isButton, let separator = text.firstIndex(of: Self.buttonSeparator) {
            argument = String(text[text.index(after: separator)...])
            text = String(text[..<separator])
        }
        let words = text.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let verb = words.first ?? ""
        let kind = vocabulary.kind(of: verb) ?? .help
        let others = Array(words.dropFirst())
        let rest = Self.textAfterVerb(original)
        return ParsedCommand(
            kind: kind,
            target: target(argument: argument, replyTo: input.replyTo, words: others),
            numbers: words.compactMap { Int($0) },
            words: others,
            rest: rest,
            argument: argument
        )
    }

    static func textAfterVerb(_ text: String) -> String {
        let parts = text.split(separator: " ", maxSplits: 1)
        return parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }

    func target(argument: String?, replyTo: Int?, words: [String]) -> ListTarget {
        if let argument, !argument.isEmpty { return .batch(argument) }
        if let replyTo { return .reply(replyTo) }
        if words.contains(where: vocabulary.emailNouns.contains) { return .emails }
        return .latest
    }
}
