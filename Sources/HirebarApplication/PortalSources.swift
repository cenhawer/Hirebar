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

public protocol WebPageFetcher: Sendable {
    func text(_ address: String) async -> String?
    func pause(_ seconds: Double) async
}

public struct PortalAccess: Sendable {
    public let jobs: [JobSource]
    public let freelance: [ListingSource]
    public let fetcher: WebPageFetcher

    public init(jobs: [JobSource], freelance: [ListingSource], fetcher: WebPageFetcher) {
        self.jobs = jobs
        self.freelance = freelance
        self.fetcher = fetcher
    }
}
