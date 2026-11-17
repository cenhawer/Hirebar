import Foundation

public enum WeekKey {
    public static func of(_ date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-S%02d", parts.yearForWeekOfYear ?? 0, parts.weekOfYear ?? 0)
    }
}
