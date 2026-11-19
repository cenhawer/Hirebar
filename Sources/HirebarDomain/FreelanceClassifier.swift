import Foundation

public enum FreelanceDiscard: Hashable, Sendable {
    case english
    case blockedWord(String)
    case titleWord(String)
    case whatsappBot
    case offProfile(String)
    case aiWithoutBackend(String)
    case asksFor(String)
    case frontendOnly(String)
    case noStackWords
    case preferredOrPrivate
    case hourlyTooLow
    case budgetTooLow

    public var text: String {
        switch self {
        case .english: return String(localized: "en inglés")
        case .blockedWord(let word): return String(localized: "palabra bloqueada \"\(word)\"")
        case .titleWord(let word): return String(localized: "título con \"\(word)\"")
        case .whatsappBot: return String(localized: "bot de WhatsApp")
        case .offProfile(let word): return String(localized: "fuera de perfil \"\(word)\"")
        case .aiWithoutBackend(let word): return String(localized: "IA sin backend (\(word))")
        case .asksFor(let word): return String(localized: "pide \(word)")
        case .frontendOnly(let word): return String(localized: "solo frontend (\(word))")
        case .noStackWords: return String(localized: "sin palabras de tu stack")
        case .preferredOrPrivate: return String(localized: "solo Preferred o privado")
        case .hourlyTooLow: return String(localized: "pago por hora muy bajo")
        case .budgetTooLow: return String(localized: "presupuesto muy bajo")
        }
    }
}

public struct FreelanceDiscardNote: Sendable, Equatable {
    public let reason: FreelanceDiscard
    public let title: String

    public init(reason: FreelanceDiscard, title: String) {
        self.reason = reason
        self.title = title
    }
}

public enum FreelanceClassifier {
    static let summaryReasons = 6
    static let summaryTitleLength = 50

    public static func looksEnglish(_ text: String) -> Bool {
        let t = TextTools.normalize(text)
        let en = TextTools.countWords(t, ["the", "and", "with", "for", "you", "we", "our", "need", "looking", "will", "to", "of", "is"])
        let es = TextTools.countWords(t, ["el", "la", "los", "las", "de", "del", "con", "para", "que", "y", "un", "una", "en", "se"])
        return en >= 3 && en > es
    }

    public static func classify(head: String, body: String, title: String = "", profile: FreelanceProfile) -> Fit? {
        verdict(head: head, body: body, title: title, profile: profile).fit
    }

    static func first(_ words: [String], in text: String) -> String? { words.first { TextTools.containsWord(text, $0) } }
    static func count(_ words: [String], in text: String) -> Int { words.filter { TextTools.containsWord(text, $0) }.count }

    static func earlyBlock(headText: String, titleText: String, allText: String, profile: FreelanceProfile) -> FreelanceDiscard? {
        if let word = first(profile.hardBlocked, in: allText) { return .blockedWord(word) }
        if let word = first(profile.titleBlocked, in: titleText) { return .titleWord(word) }
        if let word = first(profile.titleNever, in: titleText) { return .titleWord(word) }
        if titleText.contains(" whatsapp ") && profile.whatsappBotWords.contains(where: { titleText.contains($0) }) {
            return .whatsappBot
        }
        if let word = first(profile.offProfile, in: headText) { return .offProfile(word) }
        return nil
    }

    static func disqualifyAfterCounts(
        headStrong: Int, allStrong: Int, headText: String, titleText: String, allText: String, profile: FreelanceProfile
    ) -> FreelanceDiscard? {
        if headStrong == 0 && allStrong < 2, let word = first(profile.aiWords, in: titleText) { return .aiWithoutBackend(word) }
        if headStrong < 3, let word = first(profile.stackBlocked, in: allText) { return .asksFor(word) }
        if headStrong == 0, let word = first(profile.frontendOnly, in: headText) { return .frontendOnly(word) }
        return nil
    }

    static func scoreVerdict(
        headStrong: Int, allStrong: Int, headStretch: Int, allStretch: Int, offAnywhere: String?
    ) -> (fit: Fit?, reason: FreelanceDiscard?) {
        if headStrong >= 1 && allStrong >= 2 && headStretch == 0 { return (.strong, nil) }
        if headStrong >= 2 { return (.strong, nil) }
        if headStrong + headStretch >= 1 && allStrong + allStretch >= 2 { return (.stretch, nil) }
        if allStrong >= 4 && headStretch == 0 && offAnywhere == nil { return (.strong, nil) }
        if allStrong >= 2 && offAnywhere == nil { return (.stretch, nil) }
        if let offAnywhere { return (nil, .offProfile(offAnywhere)) }
        return (nil, .noStackWords)
    }

    public static func verdict(
        head: String, body: String, title: String = "", profile: FreelanceProfile
    ) -> (fit: Fit?, reason: FreelanceDiscard?) {
        if looksEnglish("\(title.isEmpty ? head : title) \(body)") { return (nil, .english) }
        let headText = TextTools.normalize(head)
        let titleText = TextTools.normalize(title.isEmpty ? head : title)
        let allText = TextTools.normalize(head + " " + body)
        if let reason = earlyBlock(headText: headText, titleText: titleText, allText: allText, profile: profile) {
            return (nil, reason)
        }
        let headStrong = count(profile.strong, in: headText)
        let allStrong = count(profile.strong, in: allText)
        if let reason = disqualifyAfterCounts(
            headStrong: headStrong, allStrong: allStrong, headText: headText, titleText: titleText, allText: allText, profile: profile
        ) {
            return (nil, reason)
        }
        let headStretch = count(profile.stretch, in: headText)
        let allStretch = count(profile.stretch, in: allText)
        let offAnywhere = first(profile.offProfile, in: allText)
        return scoreVerdict(
            headStrong: headStrong, allStrong: allStrong, headStretch: headStretch, allStretch: allStretch, offAnywhere: offAnywhere)
    }

    public static func summary(_ notes: [FreelanceDiscardNote]) -> String {
        let grouped = Dictionary(grouping: notes, by: \.reason.text)
        let ordered = grouped.sorted { $0.value.count != $1.value.count ? $0.value.count > $1.value.count : $0.key < $1.key }
        return ordered.prefix(summaryReasons).map { reason, items in
            let example = String(items[0].title.prefix(summaryTitleLength))
            return String(localized: "\(reason) \(items.count) (ej: \(example))")
        }.joined(separator: "; ")
    }
}
