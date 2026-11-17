import Foundation
import HirebarDomain

public struct EvalExpectation: Decodable, Equatable, Sendable {
    public let requireProposals: Bool
    public let allowedActions: [ActionKind]?
    public let forbiddenTexts: [String]
    public let allowedPercents: [String]?
}

public struct EvalCase: Decodable, Equatable, Sendable {
    public let id: String
    public let rules: String
    public let prompt: String
    public let page: String
    public let expect: EvalExpectation
}

public struct EvalSuite: Decodable, Equatable, Sendable {
    public let schemaVersion: Int
    public let cases: [EvalCase]
}

public enum EvalFailure: Equatable, Sendable {
    case proposalsInvalid(String)
    case actionNotAllowed(ActionKind)
    case forbiddenText(String)
    case inventedFigure(String)
}

public enum EvalGrader {
    static let noNewsMarker = "SIN_NOVEDADES"
    static let percentPattern = "[0-9]+([.,][0-9]+)?\\s?%"

    public static func grade(_ output: String, against expectation: EvalExpectation, rules: TargetRules) -> [EvalFailure] {
        var failures: [EvalFailure] = []
        var actionable = output
        if expectation.requireProposals && !output.contains(noNewsMarker) {
            switch ProposalParser.parse(output, rules: rules) {
            case .success(let proposals):
                actionable = proposals.map { [$0.target.displayText, $0.title, $0.text ?? ""].joined(separator: " ") }.joined(
                    separator: "\n")
                if let allowed = expectation.allowedActions {
                    failures += proposals.map(\.action).filter { !allowed.contains($0) }.map(EvalFailure.actionNotAllowed)
                }
            case .failure(let failure):
                failures.append(.proposalsInvalid(String(describing: failure)))
            }
        } else if expectation.requireProposals {
            actionable = ""
        }
        let lowered = actionable.lowercased()
        failures += expectation.forbiddenTexts.filter { lowered.contains($0.lowercased()) }.map(EvalFailure.forbiddenText)
        if let allowed = expectation.allowedPercents {
            failures += percents(in: output).filter { !allowed.contains($0) }.map(EvalFailure.inventedFigure)
        }
        return failures
    }

    static func percents(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: percentPattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
            .map { $0.replacingOccurrences(of: " ", with: "") }
    }
}
