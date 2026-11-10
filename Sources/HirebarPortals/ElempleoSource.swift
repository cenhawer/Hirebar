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

    let fetcher: WebPageFetcher

    public init(fetcher: WebPageFetcher) {
        self.fetcher = fetcher
    }

    public func search(skip: Set<String>, profile: SearchProfile) async -> SourceResult {
        let jobs = profile.jobs
        var hits: [Hit] = []
        var pages = 0
        var cards = 0
        for query in jobs.elempleoQueries {
            guard var components = URLComponents(string: "\(Self.base)/co/ofertas-empleo/") else { continue }
            components.queryItems = [URLQueryItem(name: "Trabajo", value: query)]
            guard let url = components.url, let data = await fetcher.data(url), let html = String(bytes: data, encoding: .utf8) else {
                continue
            }
            pages += 1
            for offer in Self.offers(in: html) {
                cards += 1
                guard !skip.contains("ee:" + offer.id), let fit = JobScreener.classify(offer.title, profile: jobs) else { continue }
                guard TextTools.normalize("\(offer.modality) \(offer.title)").contains(" remoto ") else { continue }
                if JobScreener.lowPay(offer.salary, profile: jobs) { continue }
                let age = TextTools.ageMinutes(offer.posted) ?? 600
                guard age <= Self.maxAgeMinutes else { continue }
                var detail = "elempleo · \(offer.company) · \(TextTools.ageText(age)) · remoto"
                if !offer.salary.isEmpty { detail += " · \(offer.salary)" }
                hits.append(
                    Hit(
                        id: "ee:" + offer.id, platform: name, fit: fit, title: offer.title, url: Self.base + offer.path, detail: detail,
                        score: age))
            }
            await fetcher.pause(1)
        }
        log.write("Empleo · elempleo: \(pages) páginas leídas, \(cards) ofertas vistas, \(hits.count) pasan el filtro de título")
        return SourceResult(hits: hits)
    }

    struct Offer: Equatable {
        let id: String
        let path: String
        let title: String
        let company: String
        let salary: String
        let modality: String
        let posted: String
    }

    static func offers(in html: String) -> [Offer] {
        html.components(separatedBy: "result-item").dropFirst().compactMap { card in
            guard let path = TextTools.first(card, "data-url=\"([^\"]+)\""),
                let raw = TextTools.first(card, "data-ga4-offerdata=\"([^\"]+)\""),
                let object = try? JSONSerialization.jsonObject(with: Data(TextTools.decodeEntities(raw, numeric: false).utf8))
                    as? [String: Any],
                let id = (object["id"] as? NSNumber)?.stringValue
            else { return nil }
            let text = { (key: String) in TextTools.clean(object[key] as? String ?? "") }
            return Offer(
                id: id, path: path.components(separatedBy: "?").first ?? path, title: text("title"), company: text("company"),
                salary: text("salary"), modality: TextTools.clean(TextTools.first(card, "js-work-modality[^>]*>([^<]*)<") ?? ""),
                posted: TextTools.clean(TextTools.first(card, "js-offer-date[^>]*>(?:\\s*<i[^>]*></i>)?([^<]+)<") ?? ""))
        }
    }

    public func descriptionText(from page: String) -> String? {
        PageSlice.between(page, from: "description-block", to: nil, max: 8000)
    }
}
