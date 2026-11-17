import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.portals)

public struct FreelancerSource: ListingSource {
    public let id = "freelancer"
    public let name = "Freelancer"
    static let api = "https://www.freelancer.com/api/projects/0.1/projects/active/"

    let fetcher: WebPageFetcher
    let now: PortalClock

    public init(fetcher: WebPageFetcher, now: @escaping PortalClock) {
        self.fetcher = fetcher
        self.now = now
    }

    public func search(skip: Set<String>, profile: SearchProfile) async -> SourceResult {
        let rules = profile.freelance.portals
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
            var data: Data?
            if let url = components.url { data = await fetcher.data(url) }
            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            if let result = json?["result"] as? [String: Any] {
                for project in (result["projects"] as? [[String: Any]]) ?? [] {
                    if let id = (project["id"] as? NSNumber)?.intValue { projects[id] = project }
                }
                if let found = result["users"] as? [String: Any] { users.merge(found) { old, _ in old } }
            }
            await fetcher.pause(0.6)
        }
        let now = now().timeIntervalSince1970
        var outcome = SourceResult()
        var recent = 0
        var matching = 0
        for (projectId, project) in projects {
            guard !skip.contains("f:\(projectId)") else { continue }
            let submitted = (project["time_submitted"] as? NSNumber)?.doubleValue ?? 0
            let age = Int((now - submitted) / 60)
            guard age >= 0, age <= rules.freelancerMaxAgeMinutes else { continue }
            recent += 1
            let upgrades = project["upgrades"] as? [String: Any] ?? [:]
            if (upgrades["pf_only"] as? Bool) == true || (project["nonpublic"] as? Bool) == true { continue }
            if let state = project["status"] as? String, state != "active" { continue }
            guard (project["language"] as? String ?? "en") == "es" else { continue }
            let title = project["title"] as? String ?? ""
            let description = project["description"] as? String ?? (project["preview_description"] as? String ?? "")
            let jobs = ((project["jobs"] as? [[String: Any]]) ?? []).compactMap { $0["name"] as? String }
            guard
                let fit = FreelanceClassifier.classify(
                    head: "\(title) \(jobs.joined(separator: " "))", body: description,
                    title: title, profile: profile.freelance)
            else { continue }
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
            let owner = (project["owner_id"] as? NSNumber)?.intValue
            if let state = owner.flatMap({ (users["\($0)"] as? [String: Any])?["status"] as? [String: Any] }) {
                verified = (state["payment_verified"] as? Bool) ?? false
            }
            let average = ((stats["bid_avg"] as? NSNumber)?.doubleValue ?? 0) * rate
            let seo = project["seo_url"] as? String ?? "\(projectId)"
            let range = maxUSD > 0 ? "USD \(Int(minUSD))–\(Int(maxUSD))" : "USD \(Int(minUSD))+"
            var detail = String(
                localized: "Freelancer · \(TextTools.ageText(age)) · \(bids) ofertas (prom. USD \(Int(average))) · \(range)")
            if hourly { detail += String(localized: " por hora") }
            if verified { detail += String(localized: " · pago verificado") }
            let hit = Hit(
                id: "f:\(projectId)", platform: name, fit: fit, title: title,
                url: "https://www.freelancer.com/projects/" + seo, detail: detail, score: bids)
            if fit == .strong && bids <= rules.freelancerBids.strong {
                outcome.hits.append(hit)
            } else if fit == .stretch && bids <= rules.freelancerBids.stretch {
                outcome.hits.append(hit)
            } else if bids <= rules.freelancerBids.backup {
                outcome.backup.append(hit.with(fit: .stretch, score: bids + (verified ? 0 : 10)))
            }
        }
        let found = String(
            localized: "\(projects.count) proyectos leídos, \(recent) de menos de 24 h y no vistos, \(matching) de tu perfil")
        log.write("Freelance · Freelancer: \(found), \(outcome.hits.count) avisables + \(outcome.backup.count) de respaldo")
        return outcome
    }
}
