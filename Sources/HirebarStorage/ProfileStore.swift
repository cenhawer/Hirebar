import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.storage)

extension Profile {
    public static var url: URL { Paths.workspaceFile("perfil.json") }

    public static func load() -> Profile {
        guard let data = try? Data(contentsOf: url) else { return Profile() }
        do {
            return try JSONDecoder().decode(Profile.self, from: data)
        } catch {
            log.write("perfil.json tiene un error (\(error.localizedDescription)); se ignoran las habilidades")
            return Profile()
        }
    }
}

public enum ProfileEditor {
    public typealias Outcome = SkillChange

    public static func saveSkills(_ skills: [Skill], at url: URL = Profile.url) throws {
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: url) {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CocoaError(.fileReadCorruptFile)
            }
            root = object
        }
        root["skills"] = skills.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }.map { skill -> [String: Any] in
            var entry: [String: Any] = [
                "name": skill.name.trimmingCharacters(in: .whitespaces),
                "level": skill.level.rawValue,
                "aliases": skill.aliases.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
            ]
            if let years = skill.years { entry["years"] = years }
            return entry
        }
        root[WorkspaceSchema.versionKey] = WorkspaceSchema.current
        let data = try JSONSerialization.data(withJSONObject: root, options: VersionedJSON.formatting)
        try data.write(to: url, options: .atomic)
    }

    @discardableResult
    public static func setSkill(_ name: String, level: SkillLevel, at url: URL = Profile.url) -> Outcome {
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: url) {
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failed("perfil.json no es JSON válido")
            }
            root = object
        }
        var skills = root["skills"] as? [[String: Any]] ?? []
        let wanted = TextTools.normalize(name)
        let outcome: Outcome
        if let index = skills.firstIndex(where: { TextTools.normalize($0["name"] as? String ?? "") == wanted }) {
            let previous = SkillLevel(rawValue: skills[index]["level"] as? String ?? "") ?? .familiar
            if previous == level { return .unchanged }
            skills[index]["level"] = level.rawValue
            outcome = .updated(from: previous)
        } else {
            skills.append(["name": name.trimmingCharacters(in: .whitespaces), "level": level.rawValue, "aliases": [String]()])
            outcome = .added
        }
        root["skills"] = skills
        root[WorkspaceSchema.versionKey] = WorkspaceSchema.current
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: VersionedJSON.formatting)
        else {
            return .failed("no pude guardar perfil.json")
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return .failed(error.localizedDescription)
        }
        return outcome
    }
}

extension SearchProfile {
    public static func loadEffective() -> SearchProfile {
        load().applying(Profile.load())
    }
}

public enum ProfileExperience {
    public static func pastEmployers(from url: URL = Profile.url) -> [String] {
        guard let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let experience = root["experience"] as? [[String: Any]]
        else { return [] }
        return Array(Set(experience.compactMap { $0["company"] as? String }.filter { !$0.isEmpty })).sorted()
    }

    public static func achievements(from url: URL = Profile.url) -> [String] {
        guard let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let experience = root["experience"] as? [[String: Any]]
        else { return [] }
        return experience.flatMap { job -> [String] in
            let place = [job["role"] as? String, job["company"] as? String].compactMap { $0 }.joined(separator: " en ")
            let items = (job["achievements"] as? [[String: Any]]) ?? []
            return items.compactMap { $0["text"] as? String }.map { "- \($0) (\(place))" }
        }
    }
}
