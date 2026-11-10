import Foundation
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

enum ExecutionApprovals {
    static func agent(of mode: Mode) -> AgentID {
        AgentID(rawValue: AgentKind.owner(of: mode).rawValue)
    }

    static func proposals(for batch: Batch, items: [BatchItem], store: ExecutionStateStore) -> [Proposal] {
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

    struct EmailDraft {
        let proposal: Proposal
        let kind: String
    }

    enum EmailDraftsReading {
        case none
        case invalid([String])
        case found([EmailDraft])
    }

    static func emailDrafts(
        rules: TargetRules,
        pending: Data?
    ) -> EmailDraftsReading {
        guard let data = pending,
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let emails = object["correos"] as? [[String: Any]], !emails.isEmpty
        else { return .none }
        let drafts = emails.map { email -> EmailDraft in
            let number = (email["n"] as? NSNumber).map { String($0.intValue) } ?? ""
            let kind = ((email["tipo"] as? String) ?? "").uppercased()
            let name = (email["nombre"] as? String) ?? ""
            let web = (email["web"] as? String) ?? ""
            let proposal = Proposal(
                id: number,
                action: action(forEmailType: kind),
                target: .email((email["correo"] as? String) ?? ""),
                title: (email["asunto"] as? String) ?? "",
                source: web.isEmpty ? name : "\(name) (\(web))",
                text: (email["cuerpo"] as? String) ?? ""
            )
            return EmailDraft(proposal: proposal, kind: kind)
        }
        let ids = drafts.map(\.proposal.id)
        let invalid = drafts.filter { !$0.proposal.isComplete(using: rules) || $0.proposal.title.isEmpty }.map(\.proposal.id)
        let repeated = Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        guard invalid.isEmpty, repeated.isEmpty else { return .invalid(invalid + repeated) }
        return .found(drafts)
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
