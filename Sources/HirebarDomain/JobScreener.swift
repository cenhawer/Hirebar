import Foundation

public enum Screening: Equatable, Sendable {
    case keep(Fit)
    case reject(String)
}

public enum JobScreener {
    static let portuguese = ["voce", "nao", "vaga", "desenvolvedor", "trabalho", "conhecimento", "atuacao", "sera", "experiencia em"]
    static let englishWords = ["the", "and", "with", "you", "we", "our", "will", "experience", "for", "to"]
    static let spanishWords = ["el", "la", "los", "las", "de", "con", "y", "para", "experiencia", "que"]
    static let englishRequired = [
        "ingles avanzado", "ingles fluido", "ingles conversacional", "ingles b2", "ingles c1",
        "ingles nivel b2", "ingles nivel c1", "nivel de ingles avanzado", "fluent english",
        "english fluent", "advanced english", "english b2", "english c1", "ingles intermedio alto",
        "ingles profesional", "professional english", "bilingue", "bilingual", "ingles intermedio",
        "intermediate english", "english intermediate", "ingles b1", "english b1",
        "excellent english", "english proficiency", "good english", "ingles requerido",
    ]
    static let fullyRemote = [
        " 100 remoto ", " 100 remota ", " totalmente remoto ", " totalmente remota ", " full remote ",
        " fully remote ", " remoto 100 ", " modalidad remota ", " modalidad remoto ",
        " modalidad de trabajo remoto ", " trabajo 100 remoto ", " teletrabajo total ",
        " trabajo remoto ", " modalidad trabajo remoto ", " remoto desde cualquier ", " 100 en remoto ",
        " totalmente en remoto ", " remote first ", " remoto colombia ", " 100 remota colombia ",
    ]
    static let hybrid = [
        " hibrido ", " hibrida ", " hybrid ", " on site ", " onsite ", " presencial ", " presenciales ",
        " presencialidad ", " dias en oficina ", " dias en la oficina ", " asistir a la oficina ",
    ]
    static let remoteHints = [" remoto ", " remota ", " remote ", " teletrabajo ", " home office ", " trabajo en casa ", " desde casa "]
    static let regionWide = [
        " latam ", " latinoamerica ", " america latina ", " cualquier pais ",
        " cualquier lugar ", " anywhere ", " latin america ", " hispanoamerica ",
    ]
    static let otherPlaces = [
        "argentina", "mexico", "chile", "peru", "uruguay", "montevideo", "buenos aires", "santiago",
        "lima", "brasil", "espana", "madrid", "ecuador", "guatemala", "costa rica", "estados unidos", "usa",
    ]
    static let residencyPatterns = [
        "residentes en", "residir en", "remoto desde", "remota desde", "ubicado en", "ubicada en",
        "radicado en", "radicada en", "solo", "unicamente en",
    ]
    static let backendRoles = ["backend", "back end", "back-end", "full stack", "fullstack", "full-stack"]

    public static func screen(_ raw: String, location: String = "", requireRemote: Bool = false, profile: JobProfile) -> Screening {
        let t = TextTools.normalize(raw)
        let loc = TextTools.normalize(location)
        let country = profile.country.lowercased()
        if loc.contains(" brasil ") || loc.contains(" brazil ") { return .reject("es de Brasil") }
        if TextTools.countWords(t, portuguese) >= 4 { return .reject("oferta en portugués") }
        let en = TextTools.countWords(t, englishWords)
        let es = TextTools.countWords(t, spanishWords)
        if en >= 8 && en > es { return .reject("oferta en inglés") }
        if englishRequired.contains(where: { TextTools.containsWord(t, $0) }) { return .reject("pide inglés alto") }

        let saysFullyRemote = fullyRemote.contains(where: { t.contains($0) })
        if hybrid.contains(where: { t.contains($0) }) && !saysFullyRemote { return .reject("híbrida o presencial") }
        let saysRemote = saysFullyRemote || remoteHints.contains(where: { t.contains($0) })
        if requireRemote && !saysRemote { return .reject("no dice que sea remota") }
        if !loc.trimmingCharacters(in: .whitespaces).isEmpty {
            if !TextTools.containsWord(loc, country) {
                let accepts = regionWide.contains(where: { t.contains($0) }) || TextTools.containsWord(t, country)
                if !accepts { return .reject("remoto solo para \(location)") }
            } else if location.contains(",") && !TextTools.containsWord(loc, profile.homeCity) && !saysFullyRemote {
                return .reject("sede en \(location) y no dice 100% remoto")
            }
        }
        for place in otherPlaces where place != country {
            for prefix in residencyPatterns where t.contains(" \(prefix) \(place) ") {
                if !TextTools.containsWord(t, country) && !t.contains(" latam ") && !t.contains(" latinoamerica ") {
                    return .reject("remoto solo para \(place)")
                }
            }
        }
        if !profile.hasProfessionalCard && t.contains(" tarjeta profesional ") { return .reject("exige tarjeta profesional") }
        if let top = maxYears(t), top > profile.maxYearsRequired { return .reject("pide \(top)+ años") }

        let mine = TextTools.countWords(t, profile.ownStack)
        let other = TextTools.countWords(t, profile.otherStack)
        if mine == 0 && other >= 2 { return .reject("su stack principal no es el tuyo") }
        if other > mine * 2 { return .keep(.stretch) }
        return .keep(.strong)
    }

    static func maxYears(_ normalized: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: " (\\d{1,2})\\+? (?:o mas )?(?:anos|years)") else { return nil }
        let range = NSRange(normalized.startIndex..., in: normalized)
        return regex.matches(in: normalized, range: range).compactMap { match -> Int? in
            guard let r = Range(match.range(at: 1), in: normalized) else { return nil }
            return Int(normalized[r])
        }.filter { $0 <= 20 }.max()
    }

    public static func classify(_ text: String, company: String = "", profile: JobProfile) -> Fit? {
        let t = TextTools.normalize(text)
        let c = TextTools.normalize(company)
        func hits(_ words: [String]) -> Int { words.filter { TextTools.containsWord(t, $0) }.count }
        if hits(profile.blocked) > 0 { return nil }
        if profile.blockedCompanies.contains(where: { TextTools.containsWord(c, $0) || TextTools.containsWord(t, $0) }) { return nil }
        let strong = hits(profile.strong)
        let generic = hits(profile.generic)
        let weak = hits(profile.weak)
        let backendRole = hits(backendRoles) > 0
        if hits(profile.frontendOnly) > 0 && strong == 0 && !backendRole { return nil }
        if strong >= 1 { return .strong }
        if generic >= 1 && weak == 0 { return .strong }
        if generic + weak >= 1 { return .stretch }
        return nil
    }

    public static func salaryCOP(_ text: String) -> Double? {
        let t = text.lowercased()
        guard let regex = try? NSRegularExpression(pattern: "\\d[\\d.,]*") else { return nil }
        let values: [Double] = regex.matches(in: t, range: NSRange(t.startIndex..., in: t)).compactMap { match -> Double? in
            guard let range = Range(match.range, in: t) else { return nil }
            var raw = String(t[range])
            if raw.contains(",") && raw.contains(".") {
                raw = raw.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else if raw.filter({ $0 == "." }).count > 1 {
                raw = raw.replacingOccurrences(of: ".", with: "")
            } else {
                raw = raw.replacingOccurrences(of: ",", with: ".")
            }
            return Double(raw)
        }
        guard var top = values.max() else { return nil }
        if t.contains("millon") && top < 1000 { top *= 1_000_000 }
        if t.contains("usd") || t.contains("us$") { top *= 4000 }
        return top
    }

    public static func lowPay(_ salary: String, profile: JobProfile) -> Bool {
        guard let cop = salaryCOP(salary), cop >= 100_000 else { return false }
        return cop < profile.minSalaryCOP
    }
}
