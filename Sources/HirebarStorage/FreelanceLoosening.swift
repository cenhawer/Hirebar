import Foundation
import HirebarApplication
import HirebarDomain

enum FreelanceLoosening {
    static let freelanceKey = "freelance"
    static let titleNeverKey = "titleNever"
    static let offProfileKey = "offProfile"
    static let stretchKey = "stretch"
    static let agentIdKey = "id"
    static let dailyLimitKey = "dailyLimit"

    static func searchProfile(_ root: [String: Any], with change: WorkspaceUpgrades.FreelanceLoosening) -> [String: Any] {
        guard var freelance = root[freelanceKey] as? [String: Any] else { return root }
        if let words = freelance[titleNeverKey] as? [String] {
            freelance[titleNeverKey] = words.filter { !change.quitarDeTitleNever.contains($0) }
        }
        if let words = freelance[offProfileKey] as? [String] {
            freelance[offProfileKey] = words.filter { !change.quitarDeOffProfile.contains($0) }
        }
        if let words = freelance[stretchKey] as? [String] {
            freelance[stretchKey] = words + change.agregarAStretch.filter { !words.contains($0) }
        }
        var result = root
        result[freelanceKey] = freelance
        return result
    }

    static func agent(_ root: [String: Any], with change: WorkspaceUpgrades.FreelanceLoosening) -> [String: Any] {
        guard root[agentIdKey] as? String == AgentKind.freelance.rawValue,
            let limit = (root[dailyLimitKey] as? NSNumber)?.intValue, limit < change.cupoDiarioMinimo
        else { return root }
        var result = root
        result[dailyLimitKey] = change.cupoDiarioMinimo
        return result
    }
}
