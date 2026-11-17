import Foundation
import HirebarApplication
import XCTest

final class ReleaseVersionTests: XCTestCase {
    func testEqualVersionsAreNotNewer() {
        XCTAssertFalse(ReleaseVersion.isNewer(current: "1.2.0", latest: "1.2.0"))
    }

    func testHigherPatchIsNewer() {
        XCTAssertTrue(ReleaseVersion.isNewer(current: "1.2.0", latest: "1.2.1"))
    }

    func testLowerVersionIsNotNewer() {
        XCTAssertFalse(ReleaseVersion.isNewer(current: "1.2.1", latest: "1.2.0"))
    }

    func testVPrefixIsTolerated() {
        XCTAssertTrue(ReleaseVersion.isNewer(current: "0.2.0", latest: "v0.3.0"))
    }

    func testShorterVersionPadsWithZero() {
        XCTAssertTrue(ReleaseVersion.isNewer(current: "1.2", latest: "1.2.1"))
    }

    func testUnparseableLatestIsNotNewer() {
        XCTAssertFalse(ReleaseVersion.isNewer(current: "1.2.0", latest: "nightly"))
    }
}

private struct FakeFetcher: WebPageFetcher {
    let payload: Data?
    func data(_ url: URL) async -> Data? { payload }
    func pause(_ seconds: Double) async {}
}

final class UpdateCheckerTests: XCTestCase {
    func settings() throws -> GitHubReleaseSettings {
        try GitHubReleaseSettings.decode(Data(#"{"schemaVersion": 1, "owner": "cenhawer", "repo": "Hirebar"}"#.utf8))
    }

    func testNewerReleaseReturnsInfo() async throws {
        let settings = try settings()
        let json = #"{"tag_name": "v0.3.0", "html_url": "https://github.com/cenhawer/Hirebar/releases/tag/v0.3.0"}"#
        let fetcher = FakeFetcher(payload: Data(json.utf8))
        let info = await UpdateChecker.check(settings: settings, current: "0.2.0", fetcher: fetcher)
        XCTAssertEqual(info, UpdateInfo(version: "v0.3.0", url: "https://github.com/cenhawer/Hirebar/releases/tag/v0.3.0"))
    }

    func testSameVersionReturnsNil() async throws {
        let settings = try settings()
        let json = #"{"tag_name": "v0.2.0", "html_url": "https://github.com/cenhawer/Hirebar/releases/tag/v0.2.0"}"#
        let fetcher = FakeFetcher(payload: Data(json.utf8))
        let info = await UpdateChecker.check(settings: settings, current: "0.2.0", fetcher: fetcher)
        XCTAssertNil(info)
    }

    func testNoNetworkReturnsNil() async throws {
        let settings = try settings()
        let fetcher = FakeFetcher(payload: nil)
        let info = await UpdateChecker.check(settings: settings, current: "0.2.0", fetcher: fetcher)
        XCTAssertNil(info)
    }

    func testInvalidJSONReturnsNil() async throws {
        let settings = try settings()
        let fetcher = FakeFetcher(payload: Data("not json".utf8))
        let info = await UpdateChecker.check(settings: settings, current: "0.2.0", fetcher: fetcher)
        XCTAssertNil(info)
    }
}

final class GitHubReleaseSettingsTests: XCTestCase {
    func testRejectsUnsupportedSchemaVersion() {
        let data = Data(#"{"schemaVersion": 2, "owner": "cenhawer", "repo": "Hirebar"}"#.utf8)
        XCTAssertThrowsError(try GitHubReleaseSettings.decode(data))
    }

    func testRejectsEmptyOwner() {
        let data = Data(#"{"schemaVersion": 1, "owner": "", "repo": "Hirebar"}"#.utf8)
        XCTAssertThrowsError(try GitHubReleaseSettings.decode(data))
    }
}
