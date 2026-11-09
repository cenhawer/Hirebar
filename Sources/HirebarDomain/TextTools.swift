import Foundation

public enum TextTools {
    public static func normalize(_ text: String) -> String {
        let folded = text.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
        var result = folded.replacingOccurrences(of: "[^a-z0-9.#+/]+", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\.(\\s|$)", with: " ", options: .regularExpression)
        return " " + result + " "
    }

    public static func containsWord(_ normalized: String, _ word: String) -> Bool {
        normalized.contains(" \(word) ")
    }

    public static func countWords(_ normalized: String, _ words: [String]) -> Int {
        words.reduce(0) { total, word in total + normalized.components(separatedBy: " \(word) ").count - 1 }
    }

    public static func decodeEntities(_ text: String, numeric: Bool = true) -> String {
        var result = text
        for (entity, value) in [("&quot;", "\""), ("&#039;", "'"), ("&#39;", "'"), ("&#x27;", "'"),
                                ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " ")] {
            result = result.replacingOccurrences(of: entity, with: value)
        }
        if numeric {
            for (entity, value) in [("&aacute;", "á"), ("&eacute;", "é"), ("&iacute;", "í"), ("&oacute;", "ó"),
                                    ("&uacute;", "ú"), ("&ntilde;", "ñ")] {
                result = result.replacingOccurrences(of: entity, with: value)
            }
        }
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        guard numeric, let regex = try? NSRegularExpression(pattern: "&#(\\d+);") else { return result }
        let ns = result as NSString
        var output = ""
        var last = 0
        for match in regex.matches(in: result, range: NSRange(location: 0, length: ns.length)) {
            output += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            let code = Int(ns.substring(with: match.range(at: 1))) ?? 32
            output += String(UnicodeScalar(UInt32(max(0, code))).map { Character($0) } ?? " ")
            last = match.range.location + match.range.length
        }
        output += ns.substring(from: last)
        return output
    }

    public static func clean(_ text: String) -> String {
        let noTags = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return decodeEntities(noTags)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    public static func first(_ text: String, _ pattern: String, group: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > group,
              let range = Range(match.range(at: group), in: text) else { return nil }
        return String(text[range])
    }

    public static func firstInt(_ text: String, _ pattern: String) -> Int? {
        first(text, pattern).flatMap { Int($0) }
    }

    public static func ageMinutes(_ raw: String) -> Int? {
        let t = normalize(raw)
        let n = firstInt(t, "(\\d+)")
        if t.contains(" instante") || t.contains(" segundo") || t.contains(" ahora ") || t.contains(" hoy ") { return 0 }
        if t.contains(" minuto") || t.contains(" min ") { return n ?? 1 }
        if t.contains(" casi una hora") { return 55 }
        if t.contains(" hora") { return (n ?? 1) * 60 }
        if t.contains(" ayer ") { return 1440 }
        if t.contains(" dia") { return (n ?? 1) * 1440 }
        if t.contains(" semana") { return (n ?? 1) * 10080 }
        if t.contains(" mes") { return (n ?? 1) * 43200 }
        return nil
    }

    public static func countdown(_ date: Date?) -> String {
        guard let date else { return "sin programar" }
        let seconds = Int(date.timeIntervalSinceNow)
        if seconds <= 30 { return "ahora" }
        let minutes = (seconds + 59) / 60
        if minutes < 60 { return "en \(minutes) min" }
        if minutes < 1440 { return String(format: "en %d h %02d min", minutes / 60, minutes % 60) }
        return "en \(minutes / 1440) d \(minutes % 1440 / 60) h"
    }

    public static func ageText(_ minutes: Int) -> String {
        if minutes < 60 { return "hace \(minutes) min" }
        if minutes < 1440 { return "hace \(minutes / 60) h" }
        return "hace \(minutes / 1440) d"
    }

    public static func shortTime(_ date: Date = Date()) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }
}
