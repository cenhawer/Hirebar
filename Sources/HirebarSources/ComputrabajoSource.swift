import Foundation
import HirebarApplication
import HirebarCore
import HirebarDomain

private let log = Log(.portals)

public struct ComputrabajoSource: JobSource {
    public let id = "computrabajo"
    public let name = "Computrabajo"
    public let hitPrefix = "ct"
    static let base = "https://co.computrabajo.com"

    public init() {}

    public func search(skip: Set<String>, profile: SearchProfile) async -> SourceResult {
        let jobs = profile.jobs
        var hits: [Hit] = []
        var pages = 0, cards = 0
        for slug in jobs.computrabajoSlugs {
            guard let html = await Net.fetchText("\(Self.base)/trabajo-de-\(slug)?pubdate=1") else { continue }
            pages += 1
            for card in html.components(separatedBy: "<article class=\"box_offer").dropFirst() {
                cards += 1
                guard let offerId = TextTools.first(card, "data-id=\"([A-F0-9]+)\""), !skip.contains("ct:" + offerId),
                      let href = TextTools.first(card, "js-o-link[^\"]*\" href=\"([^\"]+)\""),
                      let rawTitle = TextTools.first(card, "js-o-link[^>]*>([^<]+)<") else { continue }
                let title = TextTools.clean(rawTitle)
                guard let fit = JobScreener.classify(title, profile: jobs) else { continue }
                let modality = TextTools.clean(TextTools.first(card, "i_home_office\"></span>([^<]+)<") ?? "")
                guard TextTools.normalize("\(modality) \(title)").contains(" remoto ") else { continue }
                let salary = TextTools.clean(TextTools.first(card, "i_salary\"></span>([^<]+)<") ?? "")
                if JobScreener.lowPay(salary, profile: jobs) { continue }
                let company = TextTools.clean(TextTools.first(card, "offer-grid-article-company-url[^>]*>([^<]+)<") ?? "")
                let when = TextTools.clean(TextTools.first(card, "fc_aux mt15\">([^<]+)<") ?? "")
                let age = TextTools.ageMinutes(when) ?? 600
                let path = href.components(separatedBy: "#").first ?? href
                var detail = "Computrabajo · \(company) · \(TextTools.ageText(age)) · \(modality)"
                if !salary.isEmpty { detail += " · \(salary)" }
                hits.append(Hit(id: "ct:" + offerId, platform: name, fit: fit, title: title,
                                url: Self.base + path, detail: detail, score: age))
            }
            await Net.pause(1)
        }
        log.write("Empleo · Computrabajo: \(pages) páginas leídas, \(cards) ofertas vistas, \(hits.count) pasan el filtro de título")
        return SourceResult(hits: hits)
    }

    public func descriptionText(from page: String) -> String? {
        PageSlice.between(page, from: "Descripción de la oferta", to: nil, max: 8000)
    }
}
