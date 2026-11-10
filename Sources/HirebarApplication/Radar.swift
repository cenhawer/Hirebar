import Foundation
import HirebarDomain

public class Radar {
    public var onStatusChange: ((String) -> Void)?
    public private(set) var status = "sin buscar todavía"
    var checking = false
    private var ticker: ScheduledWork?
    private var firstRun: Date?
    private var lastStart: Date?
    private let firstDelay: TimeInterval
    private let seenKey: String
    private let seenDays: Double
    private let runState: RunStateRepository
    let clock: Clock

    init(firstDelay: TimeInterval, seenKey: String, seenDays: Double, runState: RunStateRepository, clock: Clock) {
        self.runState = runState
        self.clock = clock
        self.firstDelay = firstDelay
        self.seenKey = seenKey
        self.seenDays = seenDays
    }

    static let tickInterval: TimeInterval = 30
    static let tickTolerance: TimeInterval = 5

    var intervalMinutes: Int { 60 }

    public var nextRun: Date? {
        if let lastStart { return lastStart.addingTimeInterval(TimeInterval(intervalMinutes * 60)) }
        return firstRun
    }

    public func start() {
        ticker?.cancel()
        firstRun = clock.now().addingTimeInterval(firstDelay)
        ticker = clock.every(Self.tickInterval, tolerance: Self.tickTolerance) { [weak self] in self?.tick() }
        setStatus(status)
    }

    private func tick() {
        guard !checking, let due = nextRun, clock.now() >= due else { return }
        checkNow()
    }

    public func checkNow() {}

    func beginCheck() -> Bool {
        guard !checking else { return false }
        checking = true
        lastStart = clock.now()
        setStatus("buscando…")
        return true
    }

    func setStatus(_ text: String) {
        status = text
        onStatusChange?(text)
    }

    func seen() -> [String: Date] {
        runState.seen(seenKey)
    }

    func remember(_ hits: [Hit]) {
        let now = clock.now()
        var map = seen()
        for hit in hits { map[hit.id] = now }
        map = map.filter { now.timeIntervalSince($0.value) < seenDays * 86400 }
        runState.saveSeen(map, key: seenKey)
    }
}
