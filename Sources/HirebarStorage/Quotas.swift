import Foundation
import HirebarApplication
import HirebarDomain

public enum Quotas {
    public static var url: URL { Paths.workspaceFile("cupos.json") }

    public static func load() -> [String: PlatformQuota] {
        guard let data = try? Data(contentsOf: url),
            let quotas = try? JSONDecoder().decode([String: PlatformQuota].self, from: data)
        else { return [:] }
        return quotas
    }

    public static func day(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: String(text.prefix(10)))
    }

    public static func renewal(_ platform: String, _ quota: PlatformQuota) -> Date {
        if let text = quota.renueva, let date = day(text) { return date }
        let checked = quota.revisado.flatMap { day($0) } ?? Date()
        if platform == "workana" { return checked.addingTimeInterval(7 * 86400) }
        let calendar = Calendar.current
        var parts = calendar.dateComponents([.year, .month, .day], from: checked)
        if (parts.day ?? 1) >= 14 { parts.month = (parts.month ?? 1) + 1 }
        parts.day = 14
        return calendar.date(from: parts) ?? checked.addingTimeInterval(30 * 86400)
    }

    public static func remaining(_ platform: String) -> Int? {
        guard let quota = load()[platform], let left = quota.restantes else { return nil }
        if Date() >= renewal(platform, quota) { return nil }
        return max(0, left)
    }

    public static func exhausted(_ platform: String) -> Bool { remaining(platform) == 0 }

    public static func describe(_ platform: String) -> String {
        guard let quota = load()[platform], let left = quota.restantes else { return "sin dato" }
        let date = renewal(platform, quota)
        if Date() >= date { return "renovado (sin contar)" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_CO")
        formatter.dateFormat = "d MMM"
        let total = quota.total.map { "/\($0)" } ?? ""
        return "\(max(0, left))\(total), renueva \(formatter.string(from: date))"
    }

    public static func summary() -> String {
        "Workana \(describe("workana")) · Freelancer \(describe("freelancer"))"
    }
}
