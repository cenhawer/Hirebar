import Foundation

public struct FreelanceProfile: Codable, Sendable {
    public var workanaQueries: [String]
    public var strong: [String]
    public var stretch: [String]
    public var hardBlocked: [String]
    public var stackBlocked: [String]
    public var titleBlocked: [String]
    public var titleNever: [String]
    public var whatsappBotWords: [String]
    public var offProfile: [String]
    public var frontendOnly: [String]
    public var minFixedUSD: Double
    public var minHourlyUSD: Double

}

public struct JobProfile: Codable, Sendable {
    public var country: String
    public var homeCity: String
    public var linkedInQueries: [String]
    public var linkedInRegionalQueries: [String]
    public var linkedInContractQueries: [String]
    public var getOnBoardQueries: [String]
    public var computrabajoSlugs: [String]
    public var elempleoQueries: [String]
    public var magnetoRoles: [String]
    public var strong: [String]
    public var generic: [String]
    public var weak: [String]
    public var blocked: [String]
    public var blockedCompanies: [String]
    public var blockedTitleWords: [String]
    public var frontendOnly: [String]
    public var ownStack: [String]
    public var otherStack: [String]
    public var minSalaryCOP: Double
    public var minSalaryUSD: Int
    public var maxYearsRequired: Int
    public var hasProfessionalCard: Bool
    public var screening: JobScreeningWords

}

public struct SearchProfile: Codable, Sendable {
    public var freelance: FreelanceProfile
    public var jobs: JobProfile

    public static let supportedSchemaVersion = 1
    static var baseKey: CodingUserInfoKey? { CodingUserInfoKey(rawValue: "searchProfileBase") }

    public static func decode(_ data: Data, over base: SearchProfile?) throws -> SearchProfile {
        let decoder = JSONDecoder()
        if let key = baseKey, let base { decoder.userInfo[key] = base }
        return try decoder.decode(SearchProfile.self, from: data)
    }

    static func base(of decoder: Decoder) -> SearchProfile? {
        baseKey.flatMap { decoder.userInfo[$0] as? SearchProfile }
    }

    public init(freelance: FreelanceProfile, jobs: JobProfile) {
        self.freelance = freelance
        self.jobs = jobs
    }

    public func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try? encoder.encode(self)
    }
}

extension FreelanceProfile {
    enum CodingKeys: String, CodingKey {
        case workanaQueries, strong, stretch, hardBlocked, stackBlocked, titleBlocked, titleNever
        case whatsappBotWords, offProfile, frontendOnly, minFixedUSD, minHourlyUSD
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = SearchProfile.base(of: decoder)?.freelance
        workanaQueries = try c.decode(.workanaQueries, fallback: base?.workanaQueries)
        strong = try c.decode(.strong, fallback: base?.strong)
        stretch = try c.decode(.stretch, fallback: base?.stretch)
        hardBlocked = try c.decode(.hardBlocked, fallback: base?.hardBlocked)
        stackBlocked = try c.decode(.stackBlocked, fallback: base?.stackBlocked)
        titleBlocked = try c.decode(.titleBlocked, fallback: base?.titleBlocked)
        titleNever = try c.decode(.titleNever, fallback: base?.titleNever)
        whatsappBotWords = try c.decode(.whatsappBotWords, fallback: base?.whatsappBotWords)
        offProfile = try c.decode(.offProfile, fallback: base?.offProfile)
        frontendOnly = try c.decode(.frontendOnly, fallback: base?.frontendOnly)
        minFixedUSD = try c.decode(.minFixedUSD, fallback: base?.minFixedUSD)
        minHourlyUSD = try c.decode(.minHourlyUSD, fallback: base?.minHourlyUSD)
    }
}

extension JobProfile {
    enum CodingKeys: String, CodingKey {
        case country, homeCity, linkedInQueries, linkedInRegionalQueries, linkedInContractQueries
        case getOnBoardQueries, computrabajoSlugs, elempleoQueries, magnetoRoles
        case strong, generic, weak, blocked, blockedCompanies, blockedTitleWords, frontendOnly, ownStack, otherStack
        case minSalaryCOP, minSalaryUSD, maxYearsRequired, hasProfessionalCard, screening
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = SearchProfile.base(of: decoder)?.jobs
        country = try c.decode(.country, fallback: base?.country)
        homeCity = try c.decode(.homeCity, fallback: base?.homeCity)
        linkedInQueries = try c.decode(.linkedInQueries, fallback: base?.linkedInQueries)
        linkedInRegionalQueries = try c.decode(.linkedInRegionalQueries, fallback: base?.linkedInRegionalQueries)
        linkedInContractQueries = try c.decode(.linkedInContractQueries, fallback: base?.linkedInContractQueries)
        getOnBoardQueries = try c.decode(.getOnBoardQueries, fallback: base?.getOnBoardQueries)
        computrabajoSlugs = try c.decode(.computrabajoSlugs, fallback: base?.computrabajoSlugs)
        elempleoQueries = try c.decode(.elempleoQueries, fallback: base?.elempleoQueries)
        magnetoRoles = try c.decode(.magnetoRoles, fallback: base?.magnetoRoles)
        strong = try c.decode(.strong, fallback: base?.strong)
        generic = try c.decode(.generic, fallback: base?.generic)
        weak = try c.decode(.weak, fallback: base?.weak)
        blocked = try c.decode(.blocked, fallback: base?.blocked)
        blockedCompanies = try c.decode(.blockedCompanies, fallback: base?.blockedCompanies)
        blockedTitleWords = try c.decode(.blockedTitleWords, fallback: base?.blockedTitleWords)
        frontendOnly = try c.decode(.frontendOnly, fallback: base?.frontendOnly)
        ownStack = try c.decode(.ownStack, fallback: base?.ownStack)
        otherStack = try c.decode(.otherStack, fallback: base?.otherStack)
        minSalaryCOP = try c.decode(.minSalaryCOP, fallback: base?.minSalaryCOP)
        minSalaryUSD = try c.decode(.minSalaryUSD, fallback: base?.minSalaryUSD)
        maxYearsRequired = try c.decode(.maxYearsRequired, fallback: base?.maxYearsRequired)
        hasProfessionalCard = try c.decode(.hasProfessionalCard, fallback: base?.hasProfessionalCard)
        screening = try c.decode(.screening, fallback: base?.screening)
    }
}

extension SearchProfile {
    enum CodingKeys: String, CodingKey { case freelance, jobs }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = SearchProfile.base(of: decoder)
        freelance = try c.decode(.freelance, fallback: base?.freelance)
        jobs = try c.decode(.jobs, fallback: base?.jobs)
    }
}

public struct JobScreeningWords: Codable, Sendable {
    public var portuguese: [String]
    public var englishWords: [String]
    public var spanishWords: [String]
    public var englishRequired: [String]
    public var fullyRemote: [String]
    public var hybrid: [String]
    public var remoteHints: [String]
    public var regionWide: [String]
    public var otherPlaces: [String]
    public var residencyPatterns: [String]
    public var backendRoles: [String]
}

extension KeyedDecodingContainer {
    func decode<Value: Decodable>(_ key: Key, fallback: Value?) throws -> Value {
        if let value = try decodeIfPresent(Value.self, forKey: key) { return value }
        guard let fallback else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: key.stringValue))
        }
        return fallback
    }
}
