import Foundation
import HirebarDomain

public struct SourceResult: Sendable {
    public var hits: [Hit]
    public var backup: [Hit]

    public init(hits: [Hit] = [], backup: [Hit] = []) {
        self.hits = hits
        self.backup = backup
    }
}

public protocol ListingSource: Sendable {
    var id: String { get }
    var name: String { get }
    func search(skip: Set<String>, profile: SearchProfile) async -> SourceResult
}

public enum DescriptionCheck: Sendable {
    case skip
    case read(address: String)
}

public protocol JobSource: ListingSource {
    var hitPrefix: String { get }
    var requiresRemoteInDescription: Bool { get }
    func descriptionCheck(for hit: Hit) -> DescriptionCheck
    func descriptionText(from page: String) -> String?
    func location(from page: String) -> String
    func staleReason(page: String) -> String?
}

public extension JobSource {
    var requiresRemoteInDescription: Bool { false }
    func descriptionCheck(for hit: Hit) -> DescriptionCheck { .read(address: hit.url) }
    func descriptionText(from page: String) -> String? { TextTools.clean(page) }
    func location(from page: String) -> String { "" }
    func staleReason(page: String) -> String? { nil }

    func owns(_ hit: Hit) -> Bool { hit.id.hasPrefix(hitPrefix + ":") }
}

public enum PageSlice {
    public static func between(_ page: String, from start: String, to end: String?, max length: Int) -> String? {
        guard let a = page.range(of: start) else { return nil }
        var b = page.index(a.upperBound, offsetBy: length, limitedBy: page.endIndex) ?? page.endIndex
        if let end, let e = page.range(of: end, range: a.upperBound..<page.endIndex), e.lowerBound < b {
            b = e.lowerBound
        }
        return TextTools.clean(String(page[a.upperBound..<b]))
    }
}

public enum Catalog {
    public static let freelance: [ListingSource] = [WorkanaSource(), FreelancerSource()]
    public static let jobs: [JobSource] = [
        LinkedInSource(), GetOnBoardSource(), ComputrabajoSource(), ElempleoSource(), MagnetoSource(),
    ]
}
