import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.portals)

public struct GetOnBoardSource: JobSource {
    public let id = "getonboard"
    public let name = "Get on Board"
    public let hitPrefix = "gob"
    static let api = "https://www.getonbrd.com/api/v0/search/jobs"
    static let maxAgeMinutes = 72 * 60

    let fetcher: WebPageFetcher
    let now: PortalClock

    public init(fetcher: WebPageFetcher, now: @escaping PortalClock) {
        self.fetcher = fetcher
        self.now = now
    }

    public func descriptionCheck(for hit: Hit) -> DescriptionCheck { .skip }

    public func search(skip: Set<String>, profile: SearchProfile) async -> SourceResult {
        let jobs = profile.jobs
        let country = jobs.country.capitalized
        let now = now().timeIntervalSince1970
        var hits: [Hit] = []
        var pages = 0
        var cards = 0
        for query in jobs.getOnBoardQueries {
            guard var components = URLComponents(string: Self.api) else { continue }
            components.queryItems = [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "per_page", value: "50"),
                URLQueryItem(name: "expand", value: "[\"company\"]"),
            ]
            guard let url = components.url, let data = await fetcher.data(url),
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let list = json["data"] as? [[String: Any]]
            else { continue }
            pages += 1
            for job in list {
                cards += 1
                guard let slug = job["id"] as? String, !skip.contains("gob:" + slug),
                    let attributes = job["attributes"] as? [String: Any]
                else { continue }
                let published = (attributes["published_at"] as? NSNumber)?.doubleValue ?? 0
                let age = Int((now - published) / 60)
                guard age >= 0, age <= Self.maxAgeMinutes else { continue }
                let modality = attributes["remote_modality"] as? String ?? ""
                let countries = (attributes["countries"] as? [String]) ?? []
                guard modality == "fully_remote" || (modality == "remote_local" && countries.contains(country)) else { continue }
                let lang = (attributes["lang"] as? String ?? "").lowercased()
                if lang == "en" || lang == "lang_en" || lang.hasSuffix("english") { continue }
                let title = TextTools.clean(attributes["title"] as? String ?? slug)
                let body = ["description", "functions", "desirable", "benefits"]
                    .map { TextTools.clean(attributes[$0] as? String ?? "") }.joined(separator: " ")
                let titleNorm = TextTools.normalize(title)
                if jobs.blockedTitleWords.contains(where: { TextTools.containsWord(titleNorm, $0) }) { continue }
                let byTitle = JobScreener.classify(title, profile: jobs)
                let byText = JobScreener.classify("\(title) \(body)", profile: jobs)
                guard var fit = byTitle ?? (byText == .strong ? .stretch : nil) else { continue }
                switch JobScreener.screen(body, profile: jobs) {
                case .reject(let reason):
                    log.write("Empleo: descartada Get on Board · \(title): \(reason)")
                    continue
                case .keep(let verdict):
                    if verdict == .stretch { fit = .stretch }
                }
                let minSalary = (attributes["min_salary"] as? NSNumber)?.intValue ?? 0
                let maxSalary = (attributes["max_salary"] as? NSNumber)?.intValue ?? 0
                if maxSalary > 0 && maxSalary < jobs.minSalaryUSD { continue }
                let company =
                    ((((attributes["company"] as? [String: Any])?["data"] as? [String: Any])?["attributes"]
                        as? [String: Any])?["name"] as? String) ?? ""
                let applicants = (attributes["applications_count"] as? NSNumber)?.intValue ?? 0
                var detail = String(
                    localized: """
                        Get on Board · \(company) · \(TextTools.ageText(age)) · \(applicants) postulantes · remoto
                        """)
                if maxSalary > 0 { detail += String(localized: " · USD \(minSalary)–\(maxSalary)") }
                let link = (job["links"] as? [String: Any])?["public_url"] as? String ?? "https://www.getonbrd.com/jobs/\(slug)"
                hits.append(Hit(id: "gob:" + slug, platform: name, fit: fit, title: title, url: link, detail: detail, score: age))
            }
            await fetcher.pause(0.8)
        }
        log.write("Empleo · Get on Board: \(pages) páginas leídas, \(cards) ofertas vistas, \(hits.count) pasan el filtro de título")
        return SourceResult(hits: hits)
    }
}
