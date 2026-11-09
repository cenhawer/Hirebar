import Foundation
import HirebarApplication
import HirebarCore
import HirebarDomain

private let log = Log(.portals)

public struct LinkedInSource: JobSource {
    public let id = "linkedin"
    public let name = "LinkedIn"
    public let hitPrefix = "li"
    static let searchURL = "https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search"
    static let postingURL = "https://www.linkedin.com/jobs-guest/jobs/api/jobPosting/"
    static let regionName = "Latin America"
    static let recentWindow = "r10800"
    static let contractWindow = "r86400"

    public init() {}

    public func search(skip: Set<String>, profile: SearchProfile) async -> SourceResult {
        let jobs = profile.jobs
        let home = jobs.country.capitalized
        let searches = jobs.linkedInQueries.map { ($0, home, "") }
            + jobs.linkedInRegionalQueries.map { ($0, Self.regionName, "") }
            + jobs.linkedInContractQueries.map { ($0, home, "C,T") }
            + jobs.linkedInContractQueries.map { ($0, Self.regionName, "C,T") }
        var hits: [Hit] = []
        var pages = 0, cards = 0
        for (query, place, jobType) in searches {
            guard var components = URLComponents(string: Self.searchURL) else { continue }
            components.queryItems = [URLQueryItem(name: "keywords", value: query),
                                     URLQueryItem(name: "location", value: place),
                                     URLQueryItem(name: "f_WT", value: "2"),
                                     URLQueryItem(name: "f_TPR", value: jobType.isEmpty ? Self.recentWindow : Self.contractWindow),
                                     URLQueryItem(name: "start", value: "0")]
            if !jobType.isEmpty { components.queryItems?.append(URLQueryItem(name: "f_JT", value: jobType)) }
            guard let url = components.url, let data = await Net.fetch(url) else {
                await Net.pause(2)
                continue
            }
            let html = String(decoding: data, as: UTF8.self)
            pages += 1
            for card in html.components(separatedBy: "<li>").dropFirst() {
                cards += 1
                guard let jobId = TextTools.first(card, "urn:li:jobPosting:(\\d+)"), !skip.contains("li:" + jobId),
                      let rawTitle = TextTools.first(card, "base-search-card__title\">([^<]+)<") else { continue }
                let title = TextTools.clean(rawTitle)
                let company = TextTools.clean(TextTools.first(card, "base-search-card__subtitle\">\\s*(?:<a[^>]*>)?([^<]+)<") ?? "")
                guard let fit = JobScreener.classify(title, company: company, profile: jobs) else { continue }
                let salary = TextTools.clean(TextTools.first(card, "job-search-card__salary-info\">([^<]+)<") ?? "")
                if JobScreener.lowPay(salary, profile: jobs) { continue }
                let when = TextTools.clean(TextTools.first(card, "<time[^>]*>([\\s\\S]*?)</time>") ?? "")
                let age = TextTools.ageMinutes(when) ?? 600
                let cardPlace = TextTools.clean(TextTools.first(card, "job-search-card__location\">\\s*([^<]+)<") ?? "")
                if TextTools.normalize(cardPlace).contains(" brasil ") { continue }
                var detail = "LinkedIn · \(company) · \(TextTools.ageText(age)) · remoto" + (jobType.isEmpty ? "" : " · CONTRATO FREELANCE")
                if !cardPlace.isEmpty && !cardPlace.contains(home) { detail += " · \(cardPlace)" }
                if !salary.isEmpty { detail += " · \(salary)" }
                if hits.contains(where: { $0.id == "li:" + jobId }) { continue }
                hits.append(Hit(id: "li:" + jobId, platform: name, fit: fit, title: title,
                                url: "https://www.linkedin.com/jobs/view/\(jobId)/", detail: detail, score: age))
            }
            await Net.pause(1.5)
        }
        log.write("Empleo · LinkedIn: \(pages) páginas leídas, \(cards) ofertas vistas, \(hits.count) pasan el filtro de título")
        return SourceResult(hits: hits)
    }

    public func descriptionCheck(for hit: Hit) -> DescriptionCheck {
        .read(address: Self.postingURL + hit.id.dropFirst(hitPrefix.count + 1))
    }

    public func descriptionText(from page: String) -> String? {
        PageSlice.between(page, from: "show-more-less-html__markup", to: "description__job-criteria-list", max: 20000)
    }

    public func location(from page: String) -> String {
        TextTools.clean(TextTools.first(page, "topcard__flavor--bullet\">\\s*([^<]+)<") ?? "")
    }
}
