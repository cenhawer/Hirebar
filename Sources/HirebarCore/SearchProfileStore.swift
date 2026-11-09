import Foundation
import HirebarDomain

extension SearchProfile {
    public static func load() -> SearchProfile {
        guard let data = try? Data(contentsOf: Paths.searchProfile) else { return .defaults }
        do {
            return try JSONDecoder().decode(SearchProfile.self, from: data)
        } catch {
            Log.write("search-profile.json tiene un error (\(error.localizedDescription)); se usan los valores por defecto")
            return .defaults
        }
    }
}
