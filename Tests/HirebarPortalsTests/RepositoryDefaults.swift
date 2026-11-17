import Foundation
import HirebarDomain

enum RepositoryDefaults {
    static let searchProfile: SearchProfile = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/perfil-busqueda.json")
        guard let data = try? Data(contentsOf: url), let profile = try? SearchProfile.decode(data, over: nil) else {
            fatalError("Resources/perfil-busqueda.json no se pudo leer")
        }
        return profile
    }()
}
