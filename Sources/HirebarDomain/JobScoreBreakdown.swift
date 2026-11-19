public enum ScoreDimension: String, CaseIterable, Sendable {
    case skills
    case experience
    case location
    case careerFit
}

public enum ScoreLevel: String, Codable, Sendable {
    case alto
    case medio
    case bajo
    case sinDatos
}

public struct DimensionScore: Equatable, Sendable {
    public let dimension: ScoreDimension
    public let level: ScoreLevel

    public init(dimension: ScoreDimension, level: ScoreLevel) {
        self.dimension = dimension
        self.level = level
    }

    var points: Double? {
        switch level {
        case .alto: return 100
        case .medio: return 60
        case .bajo: return 20
        case .sinDatos: return nil
        }
    }
}

public struct ScoringWeights: Codable, Sendable {
    public var skills: Double
    public var experience: Double
    public var location: Double
    public var careerFit: Double

    public init(skills: Double, experience: Double, location: Double, careerFit: Double) {
        self.skills = skills
        self.experience = experience
        self.location = location
        self.careerFit = careerFit
    }

    public static let equal = ScoringWeights(skills: 25, experience: 25, location: 25, careerFit: 25)

    func normalized() -> ScoringWeights {
        let total = skills + experience + location + careerFit
        guard total > 0 else { return .equal }
        return ScoringWeights(
            skills: skills / total * 100,
            experience: experience / total * 100,
            location: location / total * 100,
            careerFit: careerFit / total * 100
        )
    }

    func weight(for dimension: ScoreDimension) -> Double {
        switch dimension {
        case .skills: return skills
        case .experience: return experience
        case .location: return location
        case .careerFit: return careerFit
        }
    }
}

public struct JobScoreBreakdown: Equatable, Sendable {
    public let scores: [DimensionScore]
    public let total: Double

    public init(scores: [DimensionScore], weights: ScoringWeights) {
        self.scores = scores
        var weighted = 0.0
        var weightSum = 0.0
        for score in scores {
            guard let points = score.points else { continue }
            let weight = weights.weight(for: score.dimension)
            weighted += points * weight
            weightSum += weight
        }
        total = weightSum > 0 ? weighted / weightSum : 0
    }

    public func level(for dimension: ScoreDimension) -> ScoreLevel {
        scores.first { $0.dimension == dimension }?.level ?? .sinDatos
    }

    public var lines: [String] {
        ScoreDimension.allCases.map { "\($0.title): \(level(for: $0).title)" }
    }
}

extension ScoreDimension {
    public var title: String {
        switch self {
        case .skills: return String(localized: "Habilidades")
        case .experience: return String(localized: "Experiencia")
        case .location: return String(localized: "Ubicación")
        case .careerFit: return String(localized: "Alineación de carrera")
        }
    }
}

extension ScoreLevel {
    public var title: String {
        switch self {
        case .alto: return String(localized: "alto")
        case .medio: return String(localized: "medio")
        case .bajo: return String(localized: "bajo")
        case .sinDatos: return String(localized: "sin datos")
        }
    }
}
