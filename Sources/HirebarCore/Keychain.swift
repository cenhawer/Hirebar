import Foundation

public enum Keychain {
    public static let service = "Hirebar"

    public static func read(account: String) -> String? {
        let value = Shell.run("/usr/bin/security", ["find-generic-password", "-s", service, "-a", account, "-w"])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty ?? true) ? nil : value
    }

    @discardableResult
    public static func save(_ value: String, account: String) -> Bool {
        Shell.run("/usr/bin/security", ["add-generic-password", "-U", "-s", service, "-a", account, "-w", value]) != nil
    }

    @discardableResult
    public static func delete(account: String) -> Bool {
        Shell.run("/usr/bin/security", ["delete-generic-password", "-s", service, "-a", account]) != nil
    }
}
