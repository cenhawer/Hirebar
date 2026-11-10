import Foundation
import HirebarApplication
import HirebarDomain

public enum ProfileDocumentFailure: LocalizedError, Equatable {
    case newerVersion
    case unreadable

    public var errorDescription: String? {
        switch self {
        case .newerVersion: return String(localized: "perfil.json es de una versión más nueva de Hirebar")
        case .unreadable: return String(localized: "perfil.json no es JSON válido")
        }
    }
}

public enum ProfileDocumentStore {
    typealias Object = [String: Any]

    public static func load(from url: URL = Profile.url) -> ProfileDocument {
        let root = (try? Data(contentsOf: url)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? Object } ?? [:]
        var document = ProfileDocument()
        let person = root["person"] as? Object ?? [:]
        let links = person["links"] as? Object ?? [:]
        document.person.name = text(person["name"])
        document.person.headline = text(person["headline"])
        document.person.city = text(person["city"])
        document.person.country = text(person["country"])
        document.person.email = text(person["email"])
        document.person.phone = text(person["phone"])
        document.person.linkedin = text(links["linkedin"])
        document.person.github = text(links["github"])
        document.person.portfolio = text(links["portfolio"])
        let preferences = root["preferences"] as? Object ?? [:]
        let salary = preferences["salary"] as? Object ?? [:]
        document.preferences.roles = preferences["roles"] as? [String] ?? []
        document.preferences.modality = text(preferences["modality"])
        document.preferences.availability = text(preferences["availability"])
        document.preferences.copMonthly = number(salary["copMonthly"])
        document.preferences.copMinimum = number(salary["copMinimum"])
        document.preferences.usdMonthly = number(salary["usdMonthly"])
        document.preferences.usdHour = number((preferences["freelanceRate"] as? Object)?["usdHour"])
        document.experience = (root["experience"] as? [Object] ?? []).enumerated().map(experience)
        document.cvVariants = (root["cvVariants"] as? [Object] ?? []).enumerated().map { position, item in
            CVVariantEntry(
                key: text(item["id"]), title: text(item["title"]), file: text(item["file"]), focus: item["focus"] as? [String] ?? [],
                source: position)
        }
        return document
    }

    public static func save(_ document: ProfileDocument, to url: URL = Profile.url) throws {
        guard !VersionedJSON.isNewer(url) else { throw ProfileDocumentFailure.newerVersion }
        var root: Object = [:]
        if let data = try? Data(contentsOf: url) {
            guard let object = try? JSONSerialization.jsonObject(with: data) as? Object else { throw ProfileDocumentFailure.unreadable }
            root = object
        }
        root["person"] = merged(person: document.person, into: root["person"] as? Object ?? [:])
        root["preferences"] = merged(preferences: document.preferences, into: root["preferences"] as? Object ?? [:])
        let jobs = root["experience"] as? [Object] ?? []
        root["experience"] = document.experience.map { merged(job: $0, into: original(jobs, $0.source)) }
        let variants = root["cvVariants"] as? [Object] ?? []
        root["cvVariants"] = document.cvVariants.map { variant -> Object in
            var item = original(variants, variant.source)
            item["id"] = clean(variant.key)
            item["title"] = clean(variant.title)
            item["file"] = clean(variant.file)
            item["focus"] = list(variant.focus)
            return item
        }
        root[WorkspaceSchema.versionKey] = WorkspaceSchema.current
        try JSONSerialization.data(withJSONObject: root, options: VersionedJSON.formatting).write(to: url, options: .atomic)
    }

    static func experience(_ position: Int, _ item: Object) -> WorkExperience {
        let achievements = (item["achievements"] as? [Object] ?? []).enumerated().map { index, entry in
            Achievement(text: text(entry["text"]), tech: entry["tech"] as? [String] ?? [], date: text(entry["date"]), source: index)
        }
        return WorkExperience(
            role: text(item["role"]), company: text(item["company"]), type: text(item["type"]), from: text(item["from"]),
            to: text(item["to"]), achievements: achievements, source: position)
    }

    static func merged(person: PersonDetails, into original: Object) -> Object {
        var result = original
        var links = original["links"] as? Object ?? [:]
        result["name"] = clean(person.name)
        result["headline"] = clean(person.headline)
        result["city"] = clean(person.city)
        result["country"] = clean(person.country)
        result["email"] = clean(person.email)
        result["phone"] = clean(person.phone)
        links["linkedin"] = clean(person.linkedin)
        links["github"] = clean(person.github)
        links["portfolio"] = clean(person.portfolio)
        result["links"] = links
        return result
    }

    static func merged(preferences: JobPreferences, into original: Object) -> Object {
        var result = original
        var salary = original["salary"] as? Object ?? [:]
        var rate = original["freelanceRate"] as? Object ?? [:]
        result["roles"] = list(preferences.roles)
        result["modality"] = clean(preferences.modality)
        result["availability"] = clean(preferences.availability)
        salary["copMonthly"] = preferences.copMonthly
        salary["copMinimum"] = preferences.copMinimum
        salary["usdMonthly"] = preferences.usdMonthly
        rate["usdHour"] = preferences.usdHour
        result["salary"] = salary
        result["freelanceRate"] = rate
        return result
    }

    static func merged(job: WorkExperience, into original: Object) -> Object {
        var result = original
        result["role"] = clean(job.role)
        result["company"] = clean(job.company)
        result["type"] = clean(job.type)
        result["from"] = clean(job.from)
        result["to"] = job.to.isEmpty ? NSNull() : clean(job.to)
        let achievements = original["achievements"] as? [Object] ?? []
        result["achievements"] = job.achievements.map { achievement -> Object in
            var entry = Self.original(achievements, achievement.source)
            entry["text"] = clean(achievement.text)
            entry["tech"] = list(achievement.tech)
            entry["date"] = clean(achievement.date)
            return entry
        }
        return result
    }

    static func original(_ items: [Object], _ source: Int?) -> Object {
        guard let source, items.indices.contains(source) else { return [:] }
        return items[source]
    }

    static func text(_ value: Any?) -> String { (value as? String) ?? "" }

    static func number(_ value: Any?) -> Int? { (value as? NSNumber)?.intValue }

    static func clean(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }

    static func list(_ values: [String]) -> [String] { values.map(clean).filter { !$0.isEmpty } }
}
