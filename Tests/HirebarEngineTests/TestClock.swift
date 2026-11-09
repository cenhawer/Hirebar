import Foundation
import HirebarApplication

final class TestClock: Clock, @unchecked Sendable {
    final class Work: ScheduledWork {
        var cancelled = false
        func cancel() { cancelled = true }
    }

    var moment: Date
    private(set) var pending: [(at: Date, action: () -> Void)] = []

    init(_ moment: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        self.moment = moment
    }

    func now() -> Date { moment }

    func every(_ interval: TimeInterval, tolerance: TimeInterval, _ action: @escaping () -> Void) -> ScheduledWork { Work() }

    func after(_ delay: TimeInterval, _ action: @escaping () -> Void) {
        pending.append((moment.addingTimeInterval(delay), action))
    }

    func advance(by interval: TimeInterval) {
        moment = moment.addingTimeInterval(interval)
        let due = pending.filter { $0.at <= moment }
        pending.removeAll { $0.at <= moment }
        for work in due { work.action() }
    }
}
