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
    public func text(_ address: String) async -> String? { await Net.fetchText(address) }
    public func pause(_ seconds: Double) async { await Net.pause(seconds) }
}

extension PortalAccess {
    public static var bundled: PortalAccess {
        PortalAccess(
            jobs: [LinkedInSource(), GetOnBoardSource(), ComputrabajoSource(), ElempleoSource(), MagnetoSource()],
            freelance: [WorkanaSource(), FreelancerSource()],
            fetcher: NetPageFetcher())
    }
}
