import Foundation
import HirebarCore
import HirebarDomain

public struct GetOnBoardSource: JobSource {
    public let id = "getonboard"
    public let name = "Get on Board"
    public let hitPrefix = "gob"
    static let api = "https://www.getonbrd.com/api/v0/search/jobs"
    static let maxAgeMinutes = 72 * 60

    public init() {}

    public func descriptionCheck(for hit: Hit) -> DescriptionCheck { .skip }

    public func search(skip: Set<String>, profile: SearchProfile) async -> SourceResult {
        let jobs = profile.jobs
        let country = jobs.country.capitalized
        let now = Date().timeIntervalSince1970
        var hits: [Hit] = []
        var pages = 0, cards = 0
        for query in jobs.getOnBoardQueries {
            guard var components = URLComponents(string: Self.api) else { continue }
            components.queryItems = [URLQueryItem(name: "query", value: query),
                                     URLQueryItem(name: "per_page", value: "50"),
                                     URLQueryItem(name: "expand", value: "[\"company\"]")]
            guard let url = components.url, let data = await Net.fetch(url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = json["data"] as? [[String: Any]] else { continue }
            pages += 1
            for job in list {
                cards += 1
                guard let slug = job["id"] as? String, !skip.contains("gob:" + slug),
                      let a = job["attributes"] as? [String: Any] else { continue }
                let published = (a["published_at"] as? NSNumber)?.doubleValue ?? 0
                let age = Int((now - published) / 60)
                guard age >= 0, age <= Self.maxAgeMinutes else { continue }
                let modality = a["remote_modality"] as? String ?? ""
                let countries = (a["countries"] as? [String]) ?? []
                guard modality == "fully_remote" || (modality == "remote_local" && countries.contains(country)) else { continue }
                let lang = (a["lang"] as? String ?? "").lowercased()
                if lang == "en" || lang == "lang_en" || lang.hasSuffix("english") { continue }
                let title = TextTools.clean(a["title"] as? String ?? slug)
                let body = ["description", "functions", "desirable", "benefits"]
                    .map { TextTools.clean(a[$0] as? String ?? "") }.joined(separator: " ")
                let titleNorm = TextTools.normalize(title)
                if jobs.blockedTitleWords.contains(where: { TextTools.containsWord(titleNorm, $0) }) { continue }
                let byTitle = JobScreener.classify(title, profile: jobs)
                let byText = JobScreener.classify("\(title) \(body)", profile: jobs)
                guard var fit = byTitle ?? (byText == .strong ? .stretch : nil) else { continue }
                switch JobScreener.screen(body, profile: jobs) {
                case .reject(let reason):
                    Log.write("Empleo: descartada Get on Board · \(title): \(reason)")
                    continue
                case .keep(let verdict):
                    if verdict == .stretch { fit = .stretch }
                }
                let minSalary = (a["min_salary"] as? NSNumber)?.intValue ?? 0
                let maxSalary = (a["max_salary"] as? NSNumber)?.intValue ?? 0
                if maxSalary > 0 && maxSalary < jobs.minSalaryUSD { continue }
                let company = ((((a["company"] as? [String: Any])?["data"] as? [String: Any])?["attributes"]
                    as? [String: Any])?["name"] as? String) ?? ""
                let applicants = (a["applications_count"] as? NSNumber)?.intValue ?? 0
                var detail = "Get on Board · \(company) · \(TextTools.ageText(age)) · \(applicants) postulantes · remoto"
                if maxSalary > 0 { detail += " · USD \(minSalary)–\(maxSalary)" }
                let link = (job["links"] as? [String: Any])?["public_url"] as? String ?? "https://www.getonbrd.com/jobs/\(slug)"
                hits.append(Hit(id: "gob:" + slug, platform: name, fit: fit, title: title, url: link, detail: detail, score: age))
            }
            await Net.pause(0.8)
        }
        Log.write("Empleo · Get on Board: \(pages) páginas leídas, \(cards) ofertas vistas, \(hits.count) pasan el filtro de título")
        return SourceResult(hits: hits)
    }
}
