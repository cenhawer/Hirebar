import Foundation

public protocol ScheduledWork: AnyObject {
    func cancel()
}

public protocol Clock: Sendable {
    func now() -> Date
    func every(_ interval: TimeInterval, tolerance: TimeInterval, _ action: @escaping () -> Void) -> ScheduledWork
    func after(_ delay: TimeInterval, _ action: @escaping () -> Void)
}
