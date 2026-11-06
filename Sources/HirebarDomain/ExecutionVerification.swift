import Foundation

public enum ViolationReason: String, Codable, Sendable {
    case notApproved
    case actionMismatch
    case targetMismatch
    case textMismatch
    case repeated
}

public enum UnverifiedReason: String, Codable, Sendable {
    case logMissing
    case logInvalid
    case batchMismatch
}

public enum VerdictStatus: String, Codable, Sendable {
    case authorized
    case unauthorized
    case missing
}

public struct ActionVerdict: Codable, Hashable, Sendable {
    public let itemId: String
    public let status: VerdictStatus
    public let reason: ViolationReason?
    public let record: ActionRecord?

    public static func authorized(_ record: ActionRecord) -> ActionVerdict {
        ActionVerdict(itemId: record.itemId, status: .authorized, reason: nil, record: record)
    }

    public static func unauthorized(_ record: ActionRecord, _ reason: ViolationReason) -> ActionVerdict {
        ActionVerdict(itemId: record.itemId, status: .unauthorized, reason: reason, record: record)
    }

    public static func missing(_ itemId: String) -> ActionVerdict {
        ActionVerdict(itemId: itemId, status: .missing, reason: nil, record: nil)
    }
}

public enum ActionLogReading: Sendable {
    case missing
    case invalid
    case found(ActionLog)
}

public struct ExecutionVerification: Codable, Hashable, Sendable {
    public let batch: String
    public let unverifiedReason: UnverifiedReason?
    public let verdicts: [ActionVerdict]

    public var violations: [ActionVerdict] {
        verdicts.filter { $0.status == .unauthorized }
    }

    public var requiresPause: Bool {
        unverifiedReason != nil || !violations.isEmpty
    }
}

public enum ExecutionVerifier {
    public static func verify(batch: String, approved: [ApprovedItem], reading: ActionLogReading) -> ExecutionVerification {
        let log: ActionLog
        switch reading {
        case .missing:
            return ExecutionVerification(batch: batch, unverifiedReason: .logMissing, verdicts: [])
        case .invalid:
            return ExecutionVerification(batch: batch, unverifiedReason: .logInvalid, verdicts: [])
        case .found(let found):
            log = found
        }
        guard log.batch == batch, log.schemaVersion == ActionLog.currentSchemaVersion else {
            return ExecutionVerification(batch: batch, unverifiedReason: .batchMismatch, verdicts: [])
        }
        let approvedById = Dictionary(approved.map { ($0.proposal.id, $0) }) { first, _ in first }
        var completed = Set<String>()
        var reported = Set<String>()
        var verdicts: [ActionVerdict] = []
        for record in log.actions {
            reported.insert(record.itemId)
            guard let item = approvedById[record.itemId] else {
                verdicts.append(.unauthorized(record, .notApproved))
                continue
            }
            if let violation = violation(of: record, against: item.proposal, alreadyCompleted: completed) {
                verdicts.append(.unauthorized(record, violation))
                continue
            }
            if record.outcome == .done { completed.insert(record.itemId) }
            verdicts.append(.authorized(record))
        }
        let missing = approved.map(\.proposal.id).filter { !reported.contains($0) }
        return ExecutionVerification(batch: batch, unverifiedReason: nil, verdicts: verdicts + missing.map(ActionVerdict.missing))
    }

    static func violation(of record: ActionRecord, against proposal: Proposal, alreadyCompleted: Set<String>) -> ViolationReason? {
        if record.action != proposal.action { return .actionMismatch }
        guard record.outcome == .done else { return nil }
        if alreadyCompleted.contains(record.itemId) { return .repeated }
        if !record.target.matches(proposal.target) { return .targetMismatch }
        if proposal.action.requiresText && comparable(record.sentText) != comparable(proposal.text) { return .textMismatch }
        return nil
    }

    static func comparable(_ text: String?) -> String {
        (text ?? "").replacingOccurrences(of: "\r\n", with: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
