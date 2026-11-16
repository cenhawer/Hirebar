import Foundation

public enum ReleaseVersion {
    public static func isNewer(current: String, latest: String) -> Bool {
        guard let currentComponents = components(from: current), let latestComponents = components(from: latest) else {
            return false
        }
        let count = max(currentComponents.count, latestComponents.count)
        for index in 0..<count {
            let currentPart = index < currentComponents.count ? currentComponents[index] : 0
            let latestPart = index < latestComponents.count ? latestComponents[index] : 0
            if latestPart != currentPart { return latestPart > currentPart }
        }
        return false
    }

    private static func components(from version: String) -> [Int]? {
        var text = version
        if text.hasPrefix("v") { text.removeFirst() }
        let parts = text.split(separator: ".")
        guard !parts.isEmpty else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard let number = Int(part) else { return nil }
            numbers.append(number)
        }
        return numbers
    }
}

public struct UpdateInfo: Equatable, Sendable {
    public let version: String
    public let url: String

    public init(version: String, url: String) {
        self.version = version
        self.url = url
    }
}

public struct GitHubReleaseSettings: Decodable, Equatable, Sendable {
    public static let fileName = "version"
    static let supportedSchemaVersion = 1

    public let schemaVersion: Int
    public let owner: String
    public let repo: String

    public static func decode(_ data: Data) throws -> GitHubReleaseSettings {
        let settings = try JSONDecoder().decode(GitHubReleaseSettings.self, from: data)
        guard settings.schemaVersion == supportedSchemaVersion else { throw ResourceFailure.unsupportedVersion(settings.schemaVersion) }
        guard !settings.owner.isEmpty, !settings.repo.isEmpty else { throw ResourceFailure.invalidValues }
        return settings
    }
}

struct GitHubRelease: Decodable {
    let tagName: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
    }
}

public enum UpdateChecker {
    public static func check(settings: GitHubReleaseSettings, current: String, fetcher: WebPageFetcher) async -> UpdateInfo? {
        guard let url = URL(string: "https://api.github.com/repos/\(settings.owner)/\(settings.repo)/releases/latest") else {
            return nil
        }
        guard let data = await fetcher.data(url) else { return nil }
        guard let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else { return nil }
        guard ReleaseVersion.isNewer(current: current, latest: release.tagName) else { return nil }
        return UpdateInfo(version: release.tagName, url: release.htmlUrl)
    }
}
