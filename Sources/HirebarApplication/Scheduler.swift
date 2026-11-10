import Foundation
import HirebarDomain

@MainActor
public final class Scheduler {
    public weak var controller: Controller?
    public weak var jobRadar: JobRadar?
    public weak var freelanceRadar: FreelanceRadar?

    let stores: Repositories
    let clock: Clock

    public init(stores: Repositories, clock: Clock) {
        self.stores = stores
        self.clock = clock
    }
    nonisolated static let cleanupHour = 19
    nonisolated static let tickInterval: TimeInterval = 60
    nonisolated static let tickTolerance: TimeInterval = 10
    nonisolated static let firstTickDelay: TimeInterval = 120

    public var onChange: (() -> Void)?
    private var timer: ScheduledWork?

    public func start() {
        timer?.cancel()
        timer = clock.every(Self.tickInterval, tolerance: Self.tickTolerance) { [weak self] in self?.tick() }
        clock.after(Self.firstTickDelay) { [weak self] in self?.tick() }
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
        guard stores.runState.claim(key) else { return }
        action()
    }

    private func tick() {
        let now = clock.now()
        for agent in stores.agents.all() where agent.enabled {
            for task in agent.tasks {
                if Self.isIdlePortalScan(task.mode, portals: stores.portals) { continue }
                guard let slot = task.dueSlot(at: now) else { continue }
                once(Self.key(for: task, day: slot.day, hour: slot.hour)) {
                    Log.write("Programador: \(agent.name) · \(task.mode.rawValue) de las \(slot.hour) h")
                    controller?.runScheduled(task.mode)
                }
            }
        }
        cleanUpWeekly(now)
        onChange?()
    }

    static func isIdlePortalScan(_ mode: Mode, portals: PortalRepository) -> Bool {
        switch mode {
        case .portalScanJobs: return portals.active(for: .jobs).isEmpty
        case .portalScanFreelance: return portals.active(for: .freelance).isEmpty
        default: return false
        }
    }

    private func cleanUpWeekly(_ now: Date) {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        let due = (weekday == 1 && hour >= Self.cleanupHour) || weekday == 2
        guard due, controller?.isIdle ?? false else { return }
        let sunday = weekday == 2 ? now.addingTimeInterval(-86400) : now
        once("sched.limpieza.\(WeekKey.of(sunday))") { stores.workspace.cleanUp() }
    }

    public func nextRun(of kind: AgentKind) -> Date? {
        let agent = stores.agents.load(kind)
        guard agent.enabled else { return nil }
        let search: Date?
        switch kind {
        case .jobs: search = jobRadar?.nextRun
        case .freelance: search = freelanceRadar?.nextRun
        default: search = nil
        }
        let active = agent.tasks.filter { !Self.isIdlePortalScan($0.mode, portals: stores.portals) }
        let tasks = active.compactMap { $0.nextStart(after: Date()) }.min()
        return [search, tasks].compactMap { $0 }.min()
    }
}
