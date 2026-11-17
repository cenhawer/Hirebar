import Foundation
import XCTest

@testable import HirebarDomain

final class ProfileDocumentTests: XCTestCase {
    func valid() -> ProfileDocument {
        var document = ProfileDocument()
        document.person.name = "Ana"
        document.person.email = "ana@correo.co"
        let job = WorkExperience(
            role: "Backend", company: "Acme", from: "2023-01", to: "2024-06", achievements: [Achievement(text: "Bajé costos")])
        document.experience = [job]
        document.cvVariants = [CVVariantEntry(key: "node", title: "Node", file: "HV_Node")]
        return document
    }

    func testACompleteProfileHasNoProblems() {
        XCTAssertEqual(valid().problems, [])
    }

    func testPersonalDataNeedsANameAndAValidEmail() {
        var document = valid()
        document.person.name = " "
        document.person.email = "ana@correo"
        XCTAssertEqual(document.problems, [.missingName, .invalidEmail("ana@correo")])
    }

    func testExperienceNeedsACompanyRealMonthsInOrderAndFilledAchievements() {
        var document = valid()
        document.experience.append(WorkExperience(role: "Sin empresa"))
        document.experience.append(
            WorkExperience(company: "Beta", from: "2024-13", to: "2023-01", achievements: [Achievement(text: "")]))
        document.experience.append(WorkExperience(company: "Gamma", from: "2024-05", to: "2024-01"))
        XCTAssertEqual(
            document.problems,
            [
                .missingCompany(position: 2), .invalidMonth(company: "Beta", value: "2024-13"), .emptyAchievement(company: "Beta"),
                .endsBeforeStart(company: "Gamma"),
            ])
    }

    func testAnOpenEndedJobIsValid() {
        var document = valid()
        document.experience[0].to = ""
        XCTAssertEqual(document.problems, [])
    }

    func testResumeVariantsNeedAnIdAFileAndUniqueIds() {
        var document = valid()
        document.cvVariants.append(CVVariantEntry(key: "node", title: "Otra", file: "HV_Otra"))
        document.cvVariants.append(CVVariantEntry(key: "net", title: "Sin archivo"))
        XCTAssertEqual(document.problems, [.repeatedVariant("node"), .incompleteVariant(position: 3)])
    }
}
