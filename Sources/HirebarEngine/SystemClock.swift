import Foundation
import HirebarApplication

public struct SystemClock: Clock {
    public init() {}

    public func now() -> Date { Date() }

    public func every(_ interval: TimeInterval, tolerance: TimeInterval, _ action: @escaping () -> Void) -> ScheduledWork {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in action() }
        timer.tolerance = tolerance
        RunLoop.main.add(timer, forMode: .common)
        return RepeatingTimer(timer: timer)
    }

    public func after(_ delay: TimeInterval, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
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
