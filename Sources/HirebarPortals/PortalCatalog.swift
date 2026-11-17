import Foundation
import HirebarApplication
import HirebarDomain

public enum PageSlice {
    public static func between(_ page: String, from start: String, to end: String?, max length: Int) -> String? {
        guard let opening = page.range(of: start) else { return nil }
        var limit = page.index(opening.upperBound, offsetBy: length, limitedBy: page.endIndex) ?? page.endIndex
        if let end, let closing = page.range(of: end, range: opening.upperBound..<page.endIndex), closing.lowerBound < limit {
            limit = closing.lowerBound
        }
        return TextTools.clean(String(page[opening.upperBound..<limit]))
    }
}

public struct NetPageFetcher: WebPageFetcher {
    public init() {}
    public func data(_ url: URL) async -> Data? { await Net.fetch(url) }
    public func pause(_ seconds: Double) async { await Net.pause(seconds) }
}

extension PortalAccess {
    public static var bundled: PortalAccess {
        let fetcher = NetPageFetcher()
        let now: PortalClock = { Date() }
        return PortalAccess(
            jobs: [
                LinkedInSource(fetcher: fetcher), GetOnBoardSource(fetcher: fetcher, now: now), ComputrabajoSource(fetcher: fetcher),
                ElempleoSource(fetcher: fetcher), MagnetoSource(fetcher: fetcher, now: now),
            ],
            freelance: [WorkanaSource(fetcher: fetcher), FreelancerSource(fetcher: fetcher, now: now)],
            fetcher: fetcher)
    }
}
