import Foundation

@MainActor
public protocol ScheduledWork: AnyObject {
    func cancel()
}

@MainActor
public protocol Clock {
    func now() -> Date
    func every(_ interval: TimeInterval, tolerance: TimeInterval, _ action: @escaping @MainActor () -> Void) -> ScheduledWork
    func after(_ delay: TimeInterval, _ action: @escaping @MainActor () -> Void)
}
