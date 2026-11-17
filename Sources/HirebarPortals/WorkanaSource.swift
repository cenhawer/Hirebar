import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.portals)

public struct WorkanaSource: ListingSource {
    public let id = "workana"
    public let name = "Workana"
    static let base = "https://www.workana.com"

    let fetcher: WebPageFetcher

    public init(fetcher: WebPageFetcher) {
        self.fetcher = fetcher
    }

    public func search(skip: Set<String>, profile: SearchProfile) async -> SourceResult {
        let queries = profile.freelance.workanaQueries
        let rules = profile.freelance.portals
        var candidates: [String: [String: Any]] = [:]
        var pages = 0
        var recent = 0
        var matching = 0
        for query in queries {
            if let html = await fetcher.text("\(Self.base)/jobs?\(query)&language=es") {
                pages += 1
                for result in Self.results(html) {
                    guard let slug = result["slug"] as? String, !skip.contains("w:" + slug), candidates[slug] == nil else { continue }
                    candidates[slug] = result
                }
            }
            await fetcher.pause(0.8)
        }
        var outcome = SourceResult()
        for (slug, result) in candidates {
            guard let age = TextTools.ageMinutes(result["postedDate"] as? String ?? ""), age <= rules.workanaMaxAgeMinutes else { continue }
            recent += 1
            let title = TextTools.clean(result["title"] as? String ?? slug)
            let description = TextTools.clean(result["description"] as? String ?? "")
            let skills = ((result["skills"] as? [[String: Any]]) ?? []).compactMap { $0["anchorText"] as? String }
            guard
                let fit = FreelanceClassifier.classify(
                    head: "\(title) \(skills.joined(separator: " "))", body: description,
                    title: title, profile: profile.freelance)
            else { continue }
            matching += 1
            let budgetText = TextTools.normalize(result["budget"] as? String ?? "")
            if rules.workanaLowBudgets.contains(where: { budgetText.contains(" \($0) ") }) { continue }
            guard let page = await fetcher.text("\(Self.base)/job/" + slug) else { continue }
            if page.contains(">Esperando depósito") { continue }
            let pageText = TextTools.clean(page)
            let bids = TextTools.firstInt(pageText, #"(\d+) Propuestas"#) ?? 0
            let verified = (result["hasVerifiedPaymentMethod"] as? Bool) ?? pageText.contains("Pago verificado")
            let budget = TextTools.clean(result["budget"] as? String ?? "")
            let detail =
                String(localized: "Workana · \(TextTools.ageText(age)) · \(bids) propuestas · \(budget)")
                + (verified ? String(localized: " · pago verificado") : "")
            let hit = Hit(
                id: "w:" + slug, platform: name, fit: fit, title: title,
                url: "\(Self.base)/job/" + slug, detail: detail, score: bids)
            if age > rules.workanaOldAfterMinutes && bids > rules.workanaOldMaxBids { continue }
            if fit == .strong && bids <= rules.workanaBids.strong {
                outcome.hits.append(hit)
            } else if fit == .stretch && bids <= rules.workanaBids.stretch {
                outcome.hits.append(hit)
            } else if bids <= rules.workanaBids.backup {
                outcome.backup.append(hit.with(fit: .stretch, score: bids + (verified ? 0 : 10)))
            }
            await fetcher.pause(0.5)
        }
        let found = String(
            localized: "\(pages)/\(queries.count) páginas leídas, \(candidates.count) proyectos no vistos, \(recent) de menos de 12 h")
        let notified = String(
            localized: """
                \(matching) de tu perfil, \(outcome.hits.count) avisables + \(outcome.backup.count) de respaldo
                """)
        log.write("Freelance · Workana: \(found), \(notified)")
        return outcome
    }

    public static func results(_ html: String) -> [[String: Any]] {
        guard let start = html.range(of: ":results-initials='") else { return [] }
        let rest = html[start.upperBound...]
        guard let end = rest.firstIndex(of: "'") else { return [] }
        let json = TextTools.decodeEntities(String(rest[..<end]), numeric: false)
        guard let data = json.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        return object["results"] as? [[String: Any]] ?? []
    }
}
