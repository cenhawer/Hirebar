import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.portals)

public struct MagnetoSource: JobSource {
    public let id = "magneto"
    public let name = "Magneto"
    public let hitPrefix = "mg"
    public let requiresRemoteInDescription = true
    static let base = "https://www.magneto365.com"

    let fetcher: WebPageFetcher
    let now: PortalClock

    public init(fetcher: WebPageFetcher, now: @escaping PortalClock) {
        self.fetcher = fetcher
        self.now = now
    }

    public func search(skip: Set<String>, profile: SearchProfile) async -> SourceResult {
        let jobs = profile.jobs
        var hits: [Hit] = []
        var seenHere = Set<String>()
        var pages = 0
        var cards = 0
        for role in jobs.magnetoRoles {
            guard let url = URL(string: "\(Self.base)/co/trabajos/ofertas-empleo-de-\(role)"),
                let data = await fetcher.data(url)
            else { continue }
            let html = String(decoding: data, as: UTF8.self)
            guard let regex = try? NSRegularExpression(pattern: "/co/empleos/([a-z0-9-]+?)-(\\d{5,})") else { continue }
            pages += 1
            for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
                cards += 1
                guard let slugRange = Range(match.range(at: 1), in: html),
                    let idRange = Range(match.range(at: 2), in: html)
                else { continue }
                let offerId = String(html[idRange])
                guard !skip.contains("mg:" + offerId), !seenHere.contains(offerId) else { continue }
                seenHere.insert(offerId)
                let title = String(html[slugRange]).replacingOccurrences(of: "-", with: " ").capitalized
                guard let fit = JobScreener.classify(title, profile: jobs) else { continue }
                hits.append(
                    Hit(
                        id: "mg:" + offerId, platform: name, fit: fit, title: title,
                        url: "\(Self.base)/co/empleos/\(html[slugRange])-\(offerId)",
                        detail: String(localized: "Magneto · revisar salario"), score: 300))
            }
            await fetcher.pause(1)
        }
        log.write("Empleo · Magneto: \(pages) páginas leídas, \(cards) ofertas vistas, \(hits.count) pasan el filtro de título")
        return SourceResult(hits: hits)
    }

    public func descriptionText(from page: String) -> String? {
        PageSlice.between(page, from: "\"@type\":\"JobPosting\"", to: "\"hiringOrganization\"", max: 20000)
    }

    public func staleReason(page: String, profile: JobProfile) -> String? {
        guard let posted = TextTools.first(page, "\"datePosted\":\"(\\d{4}-\\d{2}-\\d{2})") else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: posted),
            now().timeIntervalSince(date) > TimeInterval(profile.portals.magnetoMaxAgeDays) * 86400
        else { return nil }
        return String(localized: "publicada el \(posted)")
    }
}
