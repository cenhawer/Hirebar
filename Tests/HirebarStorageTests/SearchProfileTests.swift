import HirebarApplication
import HirebarDomain
import XCTest

@testable import HirebarStorage

final class SearchProfileTests: XCTestCase {
    func testMissingFieldsUseDefaults() throws {
        let json = #"{"jobs": {"homeCity": "medellin", "maxYearsRequired": 8}}"#
        let profile = try SearchProfile.decode(Data(json.utf8), over: RepositoryDefaults.searchProfile)
        XCTAssertEqual(profile.jobs.homeCity, "medellin")
        XCTAssertEqual(profile.jobs.maxYearsRequired, 8)
        XCTAssertEqual(profile.jobs.country, RepositoryDefaults.searchProfile.jobs.country)
        XCTAssertEqual(profile.freelance.strong, RepositoryDefaults.searchProfile.freelance.strong)
    }

    func testDefaultsRoundTrip() throws {
        let data = try XCTUnwrap(RepositoryDefaults.searchProfile.encoded())
        let back = try SearchProfile.decode(data, over: nil)
        XCTAssertEqual(back.jobs.linkedInQueries, RepositoryDefaults.searchProfile.jobs.linkedInQueries)
        XCTAssertEqual(back.freelance.minFixedUSD, 50)
    }

    func testTheDefaultsFileMustBeCompleteAndVersioned() throws {
        XCTAssertThrowsError(try SearchProfile.decodeDefaults(Data(#"{"schemaVersion": 1, "jobs": {}}"#.utf8)))
        let unversioned = try XCTUnwrap(RepositoryDefaults.searchProfile.encoded())
        XCTAssertThrowsError(try SearchProfile.decodeDefaults(unversioned)) {
            XCTAssertEqual($0 as? ResourceFailure, .unsupportedVersion(0))
        }
    }
}
