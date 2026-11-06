import Foundation
import HirebarDomain

public enum ProposalParseFailure: Error, Equatable, Sendable {
    case blockMissing
    case invalidJSON
    case unsupportedVersion(Int)
    case incomplete([String])
    case duplicateIds([String])
}

public enum ProposalParser {
    public static let beginMarker = "HIREBAR_PROPOSALS_BEGIN"
    public static let endMarker = "HIREBAR_PROPOSALS_END"
    public static let currentSchemaVersion = 1

    private struct ProposalList: Decodable {
        let schemaVersion: Int
        let proposals: [Proposal]
    }

    public static func parse(_ output: String) -> Result<[Proposal], ProposalParseFailure> {
        guard let block = lastBlock(in: output) else { return .failure(.blockMissing) }
        guard let data = block.data(using: .utf8), let list = try? JSONDecoder().decode(ProposalList.self, from: data) else {
            return .failure(.invalidJSON)
        }
        guard list.schemaVersion == currentSchemaVersion else { return .failure(.unsupportedVersion(list.schemaVersion)) }
        let incomplete = list.proposals.filter { !$0.isComplete }.map(\.id)
        guard incomplete.isEmpty else { return .failure(.incomplete(incomplete)) }
        let duplicates = Dictionary(grouping: list.proposals, by: \.id).filter { $0.value.count > 1 }.keys.sorted()
        guard duplicates.isEmpty else { return .failure(.duplicateIds(duplicates)) }
        return .success(list.proposals)
    }

    public static func removingBlock(from output: String) -> String {
        guard let begin = output.range(of: beginMarker, options: .backwards),
            let end = output.range(of: endMarker, range: begin.upperBound..<output.endIndex)
        else { return output }
        var remaining = output
        remaining.removeSubrange(begin.lowerBound..<end.upperBound)
        return remaining.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func lastBlock(in output: String) -> String? {
        guard let begin = output.range(of: beginMarker, options: .backwards),
            let end = output.range(of: endMarker, range: begin.upperBound..<output.endIndex)
        else { return nil }
        return String(output[begin.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
