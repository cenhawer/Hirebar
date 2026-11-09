import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.portals)

public struct ElempleoSource: JobSource {
    public let id = "elempleo"
    public let name = "elempleo"
    public let hitPrefix = "ee"
    static let base = "https://www.elempleo.com"
    static let maxAgeMinutes = 3 * 1440

    public init() {}

    public func search(skip: Set<String>, profile: SearchProfile) async -> SourceResult {
        let jobs = profile.jobs
        var hits: [Hit] = []
        var pages = 0, cards = 0
        for query in jobs.elempleoQueries {
            guard var components = URLComponents(string: "\(Self.base)/co/ofertas-empleo/") else { continue }
            components.queryItems = [URLQueryItem(name: "Trabajo", value: query)]
            guard let url = components.url, let data = await Net.fetch(url) else { continue }
            let html = String(decoding: data, as: UTF8.self)
            pages += 1
            for card in html.components(separatedBy: "result-item").dropFirst() {
                cards += 1
                guard let path = TextTools.first(card, "data-url=\"([^\"]+)\""),
                      let raw = TextTools.first(card, "data-ga4-offerdata=\"([^\"]+)\""),
                      let object = try? JSONSerialization.jsonObject(with: Data(TextTools.decodeEntities(raw, numeric: false).utf8)) as? [String: Any],
                      let offerId = (object["id"] as? NSNumber)?.stringValue, !skip.contains("ee:" + offerId) else { continue }
                let title = TextTools.clean(object["title"] as? String ?? "")
                guard let fit = JobScreener.classify(title, profile: jobs) else { continue }
                let modality = TextTools.clean(TextTools.first(card, "js-work-modality[^>]*>([^<]*)<") ?? "")
                guard TextTools.normalize("\(modality) \(title)").contains(" remoto ") else { continue }
                let salary = TextTools.clean(object["salary"] as? String ?? "")
                if JobScreener.lowPay(salary, profile: jobs) { continue }
                let when = TextTools.clean(TextTools.first(card, "js-offer-date[^>]*>(?:\\s*<i[^>]*></i>)?([^<]+)<") ?? "")
                let age = TextTools.ageMinutes(when) ?? 600
                guard age <= Self.maxAgeMinutes else { continue }
                let company = TextTools.clean(object["company"] as? String ?? "")
                let clean = path.components(separatedBy: "?").first ?? path
                var detail = "elempleo · \(company) · \(TextTools.ageText(age)) · remoto"
                if !salary.isEmpty { detail += " · \(salary)" }
                hits.append(Hit(id: "ee:" + offerId, platform: name, fit: fit, title: title,
                                url: Self.base + clean, detail: detail, score: age))
            }
            await Net.pause(1)
        }
        log.write("Empleo · elempleo: \(pages) páginas leídas, \(cards) ofertas vistas, \(hits.count) pasan el filtro de título")
        return SourceResult(hits: hits)
    }

    public func descriptionText(from page: String) -> String? {
        PageSlice.between(page, from: "description-block", to: nil, max: 8000)
    }
}
