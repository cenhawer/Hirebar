import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.storage)

extension SearchProfile {
    public static let fileName = "perfil-busqueda"

    public static func decodeDefaults(_ data: Data) throws -> SearchProfile {
        let version = VersionedJSON.version(of: data)
        guard version == supportedSchemaVersion else { throw ResourceFailure.unsupportedVersion(version) }
        return try decode(data, over: nil)
    }

    public static func loadDefaults(from url: URL) throws -> SearchProfile { try decodeDefaults(Data(contentsOf: url)) }

    public static func bundledDefaults(in bundle: Bundle = .main) throws -> SearchProfile {
        try decodeDefaults(BundledResource.data(fileName, in: bundle))
    }

    public static func load(defaults: SearchProfile) -> SearchProfile {
        guard let data = try? Data(contentsOf: Paths.searchProfile) else { return defaults }
        do {
            return try decode(data, over: defaults)
        } catch {
            log.write("search-profile.json tiene un error (\(error.localizedDescription)); se usan los valores por defecto")
            return defaults
        }
    }
}
