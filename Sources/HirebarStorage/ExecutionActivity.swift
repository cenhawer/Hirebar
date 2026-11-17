import Foundation
import HirebarApplication
import HirebarDomain

extension FileExecutionStateStore: ActivityRepository {
    static let practiceSuffix = ".practica.json"

    public func activity() -> [ActivityEntry] {
        verifiedActivity() + practiceActivity()
    }

    func verifiedActivity() -> [ActivityEntry] {
        storedVerifications().flatMap { stored in
            stored.verification.verdicts.compactMap { verdict -> ActivityEntry? in
                guard let record = verdict.record, let outcome = Self.outcome(of: verdict, record: record) else { return nil }
                return ActivityEntry(
                    agent: stored.agent, batch: stored.verification.batch, action: record.action, target: record.target,
                    text: record.sentText, at: record.at, outcome: outcome)
            }
        }
    }

    static func outcome(of verdict: ActionVerdict, record: ActionRecord) -> ActivityOutcome? {
        switch verdict.status {
        case .unauthorized: return .rejected
        case .authorized: return record.outcome == .done ? .sent : nil
        case .missing: return nil
        }
    }

    func practiceActivity() -> [ActivityEntry] {
        files(in: runsFolder).filter { $0.lastPathComponent.hasSuffix(Self.practiceSuffix) }.flatMap { file -> [ActivityEntry] in
            let batch = String(file.lastPathComponent.dropLast(Self.practiceSuffix.count))
            guard let log = PracticeLog.read(batch: batch, in: runsFolder) else { return [] }
            return log.wouldSend.map { proposal in
                ActivityEntry(
                    agent: AgentID(rawValue: log.agent), batch: log.batch, action: proposal.action, target: proposal.target,
                    text: proposal.text, at: log.at, outcome: .practice)
            }
        }
    }
}
