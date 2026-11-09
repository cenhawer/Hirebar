import HirebarDomain
import XCTest

@testable import HirebarStorage

final class SearchProfileTests: XCTestCase {
    func testMissingFieldsUseDefaults() throws {
        let json = #"{"jobs": {"homeCity": "medellin", "maxYearsRequired": 8}}"#
        let profile = try JSONDecoder().decode(SearchProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.jobs.homeCity, "medellin")
        XCTAssertEqual(profile.jobs.maxYearsRequired, 8)
        XCTAssertEqual(profile.jobs.country, JobProfile.defaults.country)
        XCTAssertEqual(profile.freelance.strong, FreelanceProfile.defaults.strong)
    }

    func testDefaultsRoundTrip() throws {
        let data = try XCTUnwrap(SearchProfile.defaults.encoded())
        let back = try JSONDecoder().decode(SearchProfile.self, from: data)
        XCTAssertEqual(back.jobs.linkedInQueries, JobProfile.defaults.linkedInQueries)
        XCTAssertEqual(back.freelance.minFixedUSD, 50)
    }
}
