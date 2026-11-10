import Foundation
import HirebarApplication

struct SystemClock: Clock {
    func now() -> Date { Date() }

    func every(_ interval: TimeInterval, tolerance: TimeInterval, _ action: @escaping @MainActor () -> Void) -> ScheduledWork {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in MainActor.assumeIsolated { action() } }
        timer.tolerance = tolerance
        RunLoop.main.add(timer, forMode: .common)
        return RepeatingTimer(timer: timer)
    }

    func after(_ delay: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            action()
        }
    }
}

final class RepeatingTimer: ScheduledWork {
    let timer: Timer

    init(timer: Timer) {
        self.timer = timer
    }

    func cancel() {
        timer.invalidate()
    }
}
