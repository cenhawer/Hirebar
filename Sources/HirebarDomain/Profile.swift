import Foundation

public enum SkillLevel: String, Codable, CaseIterable, Sendable {
    case expert = "domino"
    case familiar = "conozco"
    case avoid = "evito"

    public var title: String {
        switch self {
        case .expert: return "Domino"
        case .familiar: return "Conozco"
        case .avoid: return "Evito"
        }
    }

    public static func parse(_ text: String) -> SkillLevel? {
        let value = TextTools.normalize(text).trimmingCharacters(in: .whitespaces)
        switch value {
        case "domino", "dominio", "fuerte", "experto": return .expert
        case "conozco", "intermedio", "basico", "reto", "aprendiendo": return .familiar
        case "evito", "no", "nunca", "bloquear", "fuera": return .avoid
        default: return nil
        }
    }
}

public struct Skill: Codable, Sendable, Equatable {
    public var name: String
    public var level: SkillLevel
    public var years: Double?
    public var aliases: [String]

    public init(name: String, level: SkillLevel, years: Double? = nil, aliases: [String] = []) {
        self.name = name
        self.level = level
        self.years = years
        self.aliases = aliases
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        level = try c.decodeIfPresent(SkillLevel.self, forKey: .level) ?? .familiar
        years = try c.decodeIfPresent(Double.self, forKey: .years)
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
    }

    public var searchTerms: [String] {
        var seen = Set<String>()
        return ([name] + aliases)
            .map { TextTools.normalize($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

public struct CVVariant: Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var file: String
    public var focus: [String]
}

public struct Profile: Codable, Sendable {
    public var skills: [Skill]
    public var cvVariants: [CVVariant]

    public init(skills: [Skill] = [], cvVariants: [CVVariant] = []) {
        self.skills = skills
        self.cvVariants = cvVariants
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        skills = try c.decodeIfPresent([Skill].self, forKey: .skills) ?? []
        cvVariants = try c.decodeIfPresent([CVVariant].self, forKey: .cvVariants) ?? []
    }

    public func terms(_ level: SkillLevel) -> [String] {
        skills.filter { $0.level == level }.flatMap(\.searchTerms)
    }

    public func skill(named name: String) -> Skill? {
        let wanted = TextTools.normalize(name)
        return skills.first { TextTools.normalize($0.name) == wanted || $0.searchTerms.contains(wanted.trimmingCharacters(in: .whitespaces)) }
    }

    public var summary: String {
        let groups: [(SkillLevel, String)] = [(.expert, "Domino"), (.familiar, "Conozco"), (.avoid, "Evito")]
        return groups.map { level, title in
            let names = skills.filter { $0.level == level }.map(\.name)
            return "\(title): " + (names.isEmpty ? "—" : names.joined(separator: ", "))
        }.joined(separator: "\n")
    }
}

extension SearchProfile {
    public func applying(_ profile: Profile) -> SearchProfile {
        let expert = profile.terms(.expert)
        let familiar = profile.terms(.familiar)
        let avoid = profile.terms(.avoid)
        var result = self
        func merge(_ base: [String], _ extra: [String], removing: [String] = []) -> [String] {
            var seen = Set<String>()
            let blocked = Set(removing)
            return (base + extra).filter { !blocked.contains($0) && seen.insert($0).inserted }
        }
        result.freelance.strong = merge(freelance.strong, expert, removing: avoid)
        result.freelance.stretch = merge(freelance.stretch, familiar.filter { !result.freelance.strong.contains($0) }, removing: avoid)
        result.freelance.titleBlocked = merge(freelance.titleBlocked, avoid)
        result.jobs.strong = merge(jobs.strong, expert, removing: avoid)
        result.jobs.ownStack = merge(jobs.ownStack, expert, removing: avoid)
        result.jobs.weak = merge(jobs.weak, familiar.filter { !result.jobs.strong.contains($0) }, removing: avoid)
        result.jobs.blocked = merge(jobs.blocked, avoid)
        return result
    }
}
