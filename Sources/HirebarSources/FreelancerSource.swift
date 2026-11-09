import Foundation
import HirebarCore
import HirebarDomain

public struct FreelancerSource: ListingSource {
    public let id = "freelancer"
    public let name = "Freelancer"
    static let api = "https://www.freelancer.com/api/projects/0.1/projects/active/"
    static let maxAgeMinutes = 1440

    public init() {}

    public func search(skip: Set<String>, profile: SearchProfile) async -> SourceResult {
        var projects: [Int: [String: Any]] = [:]
        var users: [String: Any] = [:]
        for offset in [0, 100, 200] {
            guard var components = URLComponents(string: Self.api) else { continue }
            components.queryItems = [
                URLQueryItem(name: "limit", value: "100"), URLQueryItem(name: "offset", value: "\(offset)"),
                URLQueryItem(name: "job_details", value: "true"), URLQueryItem(name: "full_description", value: "true"),
                URLQueryItem(name: "user_details", value: "true"), URLQueryItem(name: "user_status", value: "true"),
                URLQueryItem(name: "upgrade_details", value: "true"),
                URLQueryItem(name: "languages[]", value: "es"),
            ]
            if let url = components.url, let data = await Net.fetch(url),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String: Any] {
                for project in (result["projects"] as? [[String: Any]]) ?? [] {
                    if let id = (project["id"] as? NSNumber)?.intValue { projects[id] = project }
                }
                if let found = result["users"] as? [String: Any] { users.merge(found) { old, _ in old } }
            }
            await Net.pause(0.6)
        }
        let now = Date().timeIntervalSince1970
        var outcome = SourceResult()
        var recent = 0, matching = 0
        for (projectId, project) in projects {
            guard !skip.contains("f:\(projectId)") else { continue }
            let submitted = (project["time_submitted"] as? NSNumber)?.doubleValue ?? 0
            let age = Int((now - submitted) / 60)
            guard age >= 0, age <= Self.maxAgeMinutes else { continue }
            recent += 1
            let upgrades = project["upgrades"] as? [String: Any] ?? [:]
            if (upgrades["pf_only"] as? Bool) == true || (project["nonpublic"] as? Bool) == true { continue }
            if let state = project["status"] as? String, state != "active" { continue }
            guard (project["language"] as? String ?? "en") == "es" else { continue }
            let title = project["title"] as? String ?? ""
            let description = project["description"] as? String ?? (project["preview_description"] as? String ?? "")
            let jobs = ((project["jobs"] as? [[String: Any]]) ?? []).compactMap { $0["name"] as? String }
            guard let fit = FreelanceClassifier.classify(head: "\(title) \(jobs.joined(separator: " "))", body: description,
                                                         title: title, profile: profile.freelance) else { continue }
            matching += 1
            let stats = project["bid_stats"] as? [String: Any] ?? [:]
            let bids = (stats["bid_count"] as? NSNumber)?.intValue ?? 0
            let rate = ((project["currency"] as? [String: Any])?["exchange_rate"] as? NSNumber)?.doubleValue ?? 1
            let budget = project["budget"] as? [String: Any] ?? [:]
            let minUSD = ((budget["minimum"] as? NSNumber)?.doubleValue ?? 0) * rate
            let maxUSD = ((budget["maximum"] as? NSNumber)?.doubleValue ?? 0) * rate
            let hourly = (project["type"] as? String) == "hourly"
            let top = max(minUSD, maxUSD)
            if hourly && top < profile.freelance.minHourlyUSD { continue }
            if !hourly && top < profile.freelance.minFixedUSD { continue }
            var verified = false
            if let owner = (project["owner_id"] as? NSNumber)?.intValue,
               let user = users["\(owner)"] as? [String: Any],
               let state = user["status"] as? [String: Any] {
                verified = (state["payment_verified"] as? Bool) ?? false
            }
            let average = ((stats["bid_avg"] as? NSNumber)?.doubleValue ?? 0) * rate
            let seo = project["seo_url"] as? String ?? "\(projectId)"
            let range = maxUSD > 0 ? "USD \(Int(minUSD))–\(Int(maxUSD))" : "USD \(Int(minUSD))+"
            var detail = "Freelancer · \(TextTools.ageText(age)) · \(bids) ofertas (prom. USD \(Int(average))) · \(range)"
            if hourly { detail += " por hora" }
            if verified { detail += " · pago verificado" }
            let hit = Hit(id: "f:\(projectId)", platform: name, fit: fit, title: title,
                          url: "https://www.freelancer.com/projects/" + seo, detail: detail, score: bids)
            if fit == .strong && bids <= 80 {
                outcome.hits.append(hit)
            } else if fit == .stretch && bids <= 60 {
                outcome.hits.append(hit)
            } else if bids <= 80 {
                outcome.backup.append(hit.with(fit: .stretch, score: bids + (verified ? 0 : 10)))
            }
        }
        Log.write("Freelance · Freelancer: \(projects.count) proyectos leídos, \(recent) de menos de 24 h y no vistos, \(matching) de tu perfil, \(outcome.hits.count) avisables + \(outcome.backup.count) de respaldo")
        return outcome
    }
}
