import HirebarDomain

public enum SkillChange: Equatable, Sendable {
    case added
    case updated(from: SkillLevel)
    case unchanged
    case failed(String)
}
