import Foundation
import HirebarCore
import HirebarDomain

public final class Scheduler {
    public static let shared = Scheduler()
    static let cleanupHour = 19

    public var onChange: (() -> Void)?
    private var timer: Timer?
    private let defaults = UserDefaults.standard

    public func start() {
        timer?.invalidate()
        let clock = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.tick() }
        clock.tolerance = 10
        RunLoop.main.add(clock, forMode: .common)
        timer = clock
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in self?.tick() }
    }

    static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func key(for task: AgentTask, day: Date, hour: Int) -> String {
        let base = "sched.\(task.mode.rawValue).\(dayKey(day))"
        return task.hours.count == 1 ? base : "\(base).\(hour)"
    }

    private func once(_ key: String, _ action: () -> Void) {
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        action()
    }

    private func tick() {
        let now = Date()
        for agent in AgentStore.all() where agent.enabled {
            for task in agent.tasks {
                if Self.isIdlePortalScan(task.mode) { continue }
                guard let slot = task.dueSlot(at: now) else { continue }
                once(Self.key(for: task, day: slot.day, hour: slot.hour)) {
                    Log.write("Programador: \(agent.name) · \(task.mode.rawValue) de las \(slot.hour) h")
                    Controller.shared.runScheduled(task.mode)
                }
            }
        }
        cleanUpWeekly(now)
        onChange?()
    }

    static func isIdlePortalScan(_ mode: Mode) -> Bool {
        switch mode {
        case .portalScanJobs: return PortalStore.active(for: .jobs).isEmpty
        case .portalScanFreelance: return PortalStore.active(for: .freelance).isEmpty
        default: return false
        }
    }

    private func cleanUpWeekly(_ now: Date) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        let due = (weekday == 1 && hour >= Self.cleanupHour) || weekday == 2
        guard due, Controller.shared.isIdle else { return }
        let sunday = weekday == 2 ? now.addingTimeInterval(-86400) : now
        once("sched.limpieza.\(Metrics.weekKey(sunday))") { Housekeeping.run() }
    }

    public func nextRun(of kind: AgentKind) -> Date? {
        let agent = AgentStore.load(kind)
        guard agent.enabled else { return nil }
        let search: Date?
        switch kind {
        case .jobs: search = JobRadar.shared.nextRun
        case .freelance: search = FreelanceRadar.shared.nextRun
        default: search = nil
        }
        let tasks = agent.tasks.filter { !Self.isIdlePortalScan($0.mode) }.compactMap { $0.nextStart(after: Date()) }.min()
        return [search, tasks].compactMap { $0 }.min()
    }
}
