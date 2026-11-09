import Foundation
import HirebarCore
import HirebarDomain

struct TargetRulesFile: Decodable, Sendable {
    static let fileName = "destinos"
    static let supportedSchemaVersion = 1

    let schemaVersion: Int
    let webSchemes: [String]
    let ignoredQueryParameters: [String]
    let ignoredQueryParameterPrefixes: [String]

    enum LoadFailure: Error {
        case missing
        case unsupportedVersion(Int)
    }

    var rules: TargetRules {
        TargetRules(
            ignoredQueryParameters: Set(ignoredQueryParameters),
            ignoredQueryParameterPrefixes: ignoredQueryParameterPrefixes,
            networks: Set(ContentNetwork.allCases.map(\.rawValue)),
            webSchemes: Set(webSchemes)
        )
    }

    static func load(from url: URL) throws -> TargetRules {
        let file = try JSONDecoder().decode(TargetRulesFile.self, from: Data(contentsOf: url))
        guard file.schemaVersion == supportedSchemaVersion else { throw LoadFailure.unsupportedVersion(file.schemaVersion) }
        return file.rules
    }

    static func bundled(in bundle: Bundle = .main) -> TargetRules {
        guard let url = bundle.url(forResource: fileName, withExtension: "json"), let rules = try? load(from: url) else {
            Log.write("Destinos: no encontré \(fileName).json en la app; comparo los enlaces completos")
            return TargetRules(
                ignoredQueryParameters: [], ignoredQueryParameterPrefixes: [], networks: Set(ContentNetwork.allCases.map(\.rawValue)),
                webSchemes: TargetRules.strict.webSchemes)
        }
        return rules
    }
}
