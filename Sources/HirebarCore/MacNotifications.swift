import Foundation
import UserNotifications

public enum MacNotifications {
    static let bodyLimit = 900

    static let appExtension = "app"

    static var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == appExtension }

    public static func show(title: String, body: String) {
        guard isAvailable else {
            Log.write("Aviso sin canal: \(title)")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = String(body.prefix(bodyLimit))
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { Log.write("Notificación de macOS no mostrada: \(error.localizedDescription)") }
        }
    }

    public static func requestPermission() async -> Bool {
        guard isAvailable else { return false }
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    public static func isAllowed() async -> Bool {
        guard isAvailable else { return false }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }
}
