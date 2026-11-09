import Foundation
import HirebarCore
import HirebarDomain

public class Radar {
    public var onStatusChange: ((String) -> Void)?
    public private(set) var status = "sin buscar todavía"
    var checking = false
    private var clock: Timer?
    private var firstRun: Date?
    private var lastStart: Date?
    private let firstDelay: TimeInterval
    private let seenKey: String
    private let seenDays: Double

    init(firstDelay: TimeInterval, seenKey: String, seenDays: Double) {
        self.firstDelay = firstDelay
        self.seenKey = seenKey
        self.seenDays = seenDays
    }

    var intervalMinutes: Int { 60 }

    public var nextRun: Date? {
        if let lastStart { return lastStart.addingTimeInterval(TimeInterval(intervalMinutes * 60)) }
        return firstRun
    }

    public func start() {
        clock?.invalidate()
        firstRun = Date().addingTimeInterval(firstDelay)
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        clock = timer
        setStatus(status)
    }

    private func tick() {
        guard !checking, let due = nextRun, Date() >= due else { return }
        checkNow()
    }

    public func checkNow() {}

    func beginCheck() -> Bool {
        guard !checking else { return false }
        checking = true
        lastStart = Date()
        setStatus("buscando…")
        return true
    }

    func setStatus(_ text: String) {
        status = text
        onStatusChange?(text)
    }

    func seen() -> [String: Date] {
        UserDefaults.standard.dictionary(forKey: seenKey) as? [String: Date] ?? [:]
    }

    func remember(_ hits: [Hit]) {
        let now = Date()
        var map = seen()
        for hit in hits { map[hit.id] = now }
        map = map.filter { now.timeIntervalSince($0.value) < seenDays * 86400 }
        UserDefaults.standard.set(map, forKey: seenKey)
    }
}
