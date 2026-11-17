import Foundation

public enum FreelanceClassifier {
    public static func looksEnglish(_ text: String) -> Bool {
        let t = TextTools.normalize(text)
        let en = TextTools.countWords(t, ["the", "and", "with", "for", "you", "we", "our", "need", "looking", "will", "to", "of", "is"])
        let es = TextTools.countWords(t, ["el", "la", "los", "las", "de", "del", "con", "para", "que", "y", "un", "una", "en", "se"])
        return en >= 3 && en > es
    }

    public static func classify(head: String, body: String, title: String = "", profile: FreelanceProfile) -> Fit? {
        if looksEnglish("\(title.isEmpty ? head : title) \(body)") { return nil }
        let h = TextTools.normalize(head)
        let tt = TextTools.normalize(title.isEmpty ? head : title)
        let all = TextTools.normalize(head + " " + body)
        func any(_ words: [String], in text: String) -> Bool { words.contains { TextTools.containsWord(text, $0) } }
        func count(_ words: [String], in text: String) -> Int { words.filter { TextTools.containsWord(text, $0) }.count }

        if any(profile.hardBlocked, in: all) { return nil }
        if any(profile.titleBlocked, in: tt) { return nil }
        if any(profile.titleNever, in: tt) { return nil }
        if tt.contains(" whatsapp ") && profile.whatsappBotWords.contains(where: { tt.contains($0) }) { return nil }
        if any(profile.offProfile, in: h) { return nil }
        let headStrong = count(profile.strong, in: h)
        if headStrong < 3 && any(profile.stackBlocked, in: all) { return nil }
        let headStretch = count(profile.stretch, in: h)
        let allStrong = count(profile.strong, in: all)
        let allStretch = count(profile.stretch, in: all)
        if headStrong == 0 && any(profile.frontendOnly, in: h) { return nil }
        if headStrong >= 1 && allStrong >= 2 && headStretch == 0 { return .strong }
        if headStrong >= 2 { return .strong }
        if headStrong + headStretch >= 1 && allStrong + allStretch >= 2 { return .stretch }
        let offAnywhere = any(profile.offProfile, in: all)
        if allStrong >= 4 && headStretch == 0 && !offAnywhere { return .strong }
        if allStrong >= 2 && !offAnywhere { return .stretch }
        return nil
    }
}
