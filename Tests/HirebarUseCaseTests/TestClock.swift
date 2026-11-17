import Foundation
import HirebarApplication

@MainActor
final class TestClock: Clock {
    final class Work: ScheduledWork {
        var cancelled = false
        func cancel() { cancelled = true }
    }

    var moment: Date
    private(set) var pending: [(at: Date, action: @MainActor () -> Void)] = []
    private var repeating: [(work: Work, action: @MainActor () -> Void)] = []

    init(_ moment: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        self.moment = moment
    }

    func now() -> Date { moment }

    func every(_ interval: TimeInterval, tolerance: TimeInterval, _ action: @escaping @MainActor () -> Void) -> ScheduledWork {
        let work = Work()
        repeating.append((work, action))
        return work
    }

    func after(_ delay: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        pending.append((moment.addingTimeInterval(delay), action))
    }

    func tick() {
        for entry in repeating where !entry.work.cancelled { entry.action() }
    }

    func advance(by interval: TimeInterval) {
        moment = moment.addingTimeInterval(interval)
        let due = pending.filter { $0.at <= moment }
        pending.removeAll { $0.at <= moment }
        for work in due { work.action() }
    }
}
