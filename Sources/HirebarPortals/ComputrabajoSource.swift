import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.portals)

public struct ComputrabajoSource: JobSource {
    public let id = "computrabajo"
    public let name = "Computrabajo"
    public let hitPrefix = "ct"
    static let base = "https://co.computrabajo.com"

    let fetcher: WebPageFetcher

    public init(fetcher: WebPageFetcher) {
        self.fetcher = fetcher
    }

    public func search(skip: Set<String>, profile: SearchProfile) async -> SourceResult {
        let jobs = profile.jobs
        var hits: [Hit] = []
        var pages = 0
        var cards = 0
        for slug in jobs.computrabajoSlugs {
            guard let html = await fetcher.text("\(Self.base)/trabajo-de-\(slug)?pubdate=1") else { continue }
            pages += 1
            for offer in Self.offers(in: html) {
                cards += 1
                guard !skip.contains("ct:" + offer.id), let fit = JobScreener.classify(offer.title, profile: jobs) else { continue }
                guard TextTools.normalize("\(offer.modality) \(offer.title)").contains(" remoto ") else { continue }
                if JobScreener.lowPay(offer.salary, profile: jobs) { continue }
                let age = TextTools.ageMinutes(offer.posted) ?? 600
                var detail = "Computrabajo · \(offer.company) · \(TextTools.ageText(age)) · \(offer.modality)"
                if !offer.salary.isEmpty { detail += " · \(offer.salary)" }
                hits.append(
                    Hit(
                        id: "ct:" + offer.id, platform: name, fit: fit, title: offer.title, url: Self.base + offer.path, detail: detail,
                        score: age))
            }
            await fetcher.pause(1)
        }
        log.write("Empleo · Computrabajo: \(pages) páginas leídas, \(cards) ofertas vistas, \(hits.count) pasan el filtro de título")
        return SourceResult(hits: hits)
    }

    struct Offer: Equatable {
        let id: String
        let path: String
        let title: String
        let modality: String
        let salary: String
        let company: String
        let posted: String
    }

    static func offers(in html: String) -> [Offer] {
        html.components(separatedBy: "<article class=\"box_offer").dropFirst().compactMap { card in
            guard let id = TextTools.first(card, "data-id=[\"']([A-F0-9]+)[\"']"),
                let href = TextTools.first(card, "js-o-link[^\"]*\" href=\"([^\"]+)\""),
                let title = TextTools.first(card, "js-o-link[^>]*>([^<]+)<")
            else { return nil }
            let field = { (pattern: String) in TextTools.clean(TextTools.first(card, pattern) ?? "") }
            return Offer(
                id: id, path: href.components(separatedBy: "#").first ?? href, title: TextTools.clean(title),
                modality: field("i_home_office[^\"]*\"></span>([^<]+)<"), salary: field("i_salary[^\"]*\"></span>([^<]+)<"),
                company: field("offer-grid-article-company-url[^>]*>([^<]+)<"), posted: field("fc_aux mt15\">([^<]+)<"))
        }
    }

    public func descriptionText(from page: String) -> String? {
        PageSlice.between(page, from: "Descripción de la oferta", to: nil, max: 8000)
    }
}
