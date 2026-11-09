import Foundation
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

public enum AI {
    public static var settings: AIEngineSettings { Config.load().aiEngine }
    public static var name: String { settings.displayName }
    public static var capitalizedName: String { name.prefix(1).uppercased() + name.dropFirst() }
}
