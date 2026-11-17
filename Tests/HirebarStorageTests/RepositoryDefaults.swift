import Foundation
import HirebarApplication
import HirebarDomain

enum RepositoryDefaults {
    static let resources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Resources")

    static let retention: RetentionPolicy = {
        guard let policy = try? RetentionPolicy.decode(Data(contentsOf: resources.appendingPathComponent("retencion.json"))) else {
            fatalError("Resources/retencion.json no se pudo leer")
        }
        return policy
    }()

    static let searchProfile: SearchProfile = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/perfil-busqueda.json")
        guard let data = try? Data(contentsOf: url), let profile = try? SearchProfile.decode(data, over: nil) else {
            fatalError("Resources/perfil-busqueda.json no se pudo leer")
        }
        return profile
    }()
}
