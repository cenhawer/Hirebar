import Foundation

public struct PersonDetails: Equatable, Sendable {
    public var name = ""
    public var headline = ""
    public var city = ""
    public var country = ""
    public var email = ""
    public var phone = ""
    public var linkedin = ""
    public var github = ""
    public var portfolio = ""

    public init() {}
}

public struct JobPreferences: Equatable, Sendable {
    public var roles: [String] = []
    public var modality = ""
    public var availability = ""
    public var copMonthly: Int?
    public var copMinimum: Int?
    public var usdMonthly: Int?
    public var usdHour: Int?

    public init() {}
}

public struct Achievement: Equatable, Sendable, Identifiable {
    public let id = UUID()
    public var text = ""
    public var tech: [String] = []
    public var date = ""
    public var source: Int?

    public init(text: String = "", tech: [String] = [], date: String = "", source: Int? = nil) {
        self.text = text
        self.tech = tech
        self.date = date
        self.source = source
    }

    public static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.text == rhs.text && lhs.tech == rhs.tech && lhs.date == rhs.date && lhs.source == rhs.source
    }
}

public struct WorkExperience: Equatable, Sendable, Identifiable {
    public let id = UUID()
    public var role = ""
    public var company = ""
    public var type = ""
    public var from = ""
    public var to = ""
    public var achievements: [Achievement] = []
    public var source: Int?

    public init(
        role: String = "", company: String = "", type: String = "", from: String = "", to: String = "",
        achievements: [Achievement] = [], source: Int? = nil
    ) {
        self.role = role
        self.company = company
        self.type = type
        self.from = from
        self.to = to
        self.achievements = achievements
        self.source = source
    }

    public static func == (lhs: WorkExperience, rhs: WorkExperience) -> Bool {
        lhs.role == rhs.role && lhs.company == rhs.company && lhs.type == rhs.type && lhs.from == rhs.from && lhs.to == rhs.to
            && lhs.achievements == rhs.achievements && lhs.source == rhs.source
    }
}

public struct CVVariantEntry: Equatable, Sendable, Identifiable {
    public let id = UUID()
    public var key = ""
    public var title = ""
    public var file = ""
    public var focus: [String] = []
    public var source: Int?

    public init(key: String = "", title: String = "", file: String = "", focus: [String] = [], source: Int? = nil) {
        self.key = key
        self.title = title
        self.file = file
        self.focus = focus
        self.source = source
    }

    public static func == (lhs: CVVariantEntry, rhs: CVVariantEntry) -> Bool {
        lhs.key == rhs.key && lhs.title == rhs.title && lhs.file == rhs.file && lhs.focus == rhs.focus && lhs.source == rhs.source
    }
}

public enum ProfileProblem: Equatable, Sendable {
    case missingName
    case invalidEmail(String)
    case missingCompany(position: Int)
    case invalidMonth(company: String, value: String)
    case endsBeforeStart(company: String)
    case emptyAchievement(company: String)
    case incompleteVariant(position: Int)
    case repeatedVariant(String)
}

public struct ProfileDocument: Equatable, Sendable {
    public var person = PersonDetails()
    public var preferences = JobPreferences()
    public var experience: [WorkExperience] = []
    public var cvVariants: [CVVariantEntry] = []

    public init() {}

    public var problems: [ProfileProblem] {
        var found: [ProfileProblem] = []
        if person.name.trimmingCharacters(in: .whitespaces).isEmpty { found.append(.missingName) }
        let email = person.email.trimmingCharacters(in: .whitespaces)
        if !email.isEmpty && !Self.looksLikeEmail(email) { found.append(.invalidEmail(email)) }
        for (position, job) in experience.enumerated() { found += Self.problems(of: job, position: position + 1) }
        var keys = Set<String>()
        for (position, variant) in cvVariants.enumerated() {
            let key = variant.key.trimmingCharacters(in: .whitespaces)
            if key.isEmpty || variant.file.trimmingCharacters(in: .whitespaces).isEmpty {
                found.append(.incompleteVariant(position: position + 1))
            } else if !keys.insert(key).inserted {
                found.append(.repeatedVariant(key))
            }
        }
        return found
    }

    static func problems(of job: WorkExperience, position: Int) -> [ProfileProblem] {
        let company = job.company.trimmingCharacters(in: .whitespaces)
        guard !company.isEmpty else { return [.missingCompany(position: position)] }
        var found: [ProfileProblem] = []
        for value in [job.from, job.to] where !value.isEmpty && !isMonth(value) {
            found.append(.invalidMonth(company: company, value: value))
        }
        if isMonth(job.from) && isMonth(job.to) && job.to < job.from { found.append(.endsBeforeStart(company: company)) }
        if job.achievements.contains(where: { $0.text.trimmingCharacters(in: .whitespaces).isEmpty }) {
            found.append(.emptyAchievement(company: company))
        }
        return found
    }

    static func isMonth(_ value: String) -> Bool {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 4, parts[1].count == 2, let month = Int(parts[1]), Int(parts[0]) != nil else {
            return false
        }
        return (1...12).contains(month)
    }

    static func looksLikeEmail(_ value: String) -> Bool {
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !value.contains(" ") else { return false }
        let domain = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        return domain.count >= 2 && domain.allSatisfy { !$0.isEmpty }
    }
}
