import Foundation
import HirebarApplication
import HirebarCore
import HirebarDomain

enum ExecutionApprovals {
    static let store = FileExecutionStateStore.standard

    static func agent(of mode: Mode) -> AgentID {
        AgentID(rawValue: AgentKind.owner(of: mode).rawValue)
    }

    static func proposals(for batch: Batch, items: [BatchItem]) -> [Proposal] {
        let stored = Dictionary(store.proposals(batch: batch.id).map { ($0.id, $0) }) { first, _ in first }
        return items.compactMap { stored[$0.id] ?? proposal(from: $0, mode: batch.mode) }
    }

    static func proposal(from item: BatchItem, mode: Mode) -> Proposal? {
        let action: ActionKind
        switch mode {
        case .jobs: action = .apply
        case .freelance: action = .sendProposal
        default: return nil
        }
        return Proposal(
            id: item.id, action: action, target: .url(item.url), title: item.title, source: item.platform,
            fit: FitLevel(rawValue: item.kind))
    }

    static func emailProposals(
        pending: URL = Paths.prospecting.appendingPathComponent("pendientes.json"),
        approved: URL = Paths.prospecting.appendingPathComponent("aprobados.json")
    ) -> [Proposal] {
        guard let pendingData = try? Data(contentsOf: pending),
            let pendingObject = try? JSONSerialization.jsonObject(with: pendingData) as? [String: Any],
            let emails = pendingObject["correos"] as? [[String: Any]],
            let approvedData = try? Data(contentsOf: approved),
            let approvedObject = try? JSONSerialization.jsonObject(with: approvedData) as? [String: Any]
        else { return [] }
        let selection = approvedObject["aprobados"]
        let numbers = (selection as? [NSNumber]).map { Set($0.map(\.intValue)) }
        guard numbers != nil || (selection as? String) == "todos" else { return [] }
        return emails.compactMap { email in
            guard let number = (email["n"] as? NSNumber)?.intValue, numbers?.contains(number) ?? true,
                let address = email["correo"] as? String, let body = email["cuerpo"] as? String
            else { return nil }
            return Proposal(
                id: String(number),
                action: action(forEmailType: email["tipo"] as? String),
                target: .email(address),
                title: (email["nombre"] as? String) ?? address,
                source: (email["web"] as? String) ?? "",
                text: body
            )
        }
    }

    static func action(forEmailType type: String?) -> ActionKind {
        switch (type ?? "").uppercased() {
        case "RESPUESTA": return .replyToClient
        case "SEGUIMIENTO": return .sendFollowUp
        default: return .sendEmail
        }
    }

    static func publishProposal(_ account: ContentAccount) -> Proposal? {
        guard let text = try? String(contentsOf: account.draft, encoding: .utf8),
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return Proposal(
            id: account.id,
            action: .publish,
            target: .account(network: account.network.rawValue, handle: account.handle.isEmpty ? account.id : account.handle),
            title: account.title,
            source: account.network.title,
            text: text
        )
    }

    static func targetJSON(_ target: Target) -> String {
        guard let data = try? JSONEncoder().encode(target), let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}
