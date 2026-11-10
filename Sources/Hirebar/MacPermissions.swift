import HirebarApplication
import HirebarMedia
import HirebarNotifications

struct MacPermissions: SystemPermissions {
    func state(of permission: SystemPermission) async -> PermissionState {
        switch permission {
        case .voiceRecognition: return VoiceListener.permissionState()
        case .notifications: return await MacNotifications.permissionState()
        }
    }

    func request(_ permission: SystemPermission) async -> PermissionState {
        switch permission {
        case .voiceRecognition: return await VoiceListener.requestPermission()
        case .notifications:
            _ = await MacNotifications.requestPermission()
            return await MacNotifications.permissionState()
        }
    }
}
