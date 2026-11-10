import Foundation
import HirebarDomain

extension Controller {
    public func pendingLists() -> [InboxList] {
        PendingInbox.lists(from: stores.batches.load())
    }

    public func pendingDrafts() -> [InboxDraft] {
        let accounts = stores.contentAccounts
        return accounts.enabled().filter(accounts.hasDraft).map { account in
            InboxDraft(
                id: account.id, title: account.title, text: accounts.draftText(account) ?? "",
                slides: accounts.slideImages(account), video: accounts.videoPreview(account))
        }
    }

    public func approveList(_ id: String, picks: [Int]) {
        approve(stores.batches.find(id: id), picks: picks)
    }

    public func discardPendingList(_ id: String) {
        discardList(stores.batches.find(id: id))
    }

    public func publishDraft(of accountId: String) {
        guard let account = stores.contentAccounts.find(accountId), stores.contentAccounts.hasDraft(account) else {
            reply(String(localized: "No tengo publicaciones pendientes. Escribe \"post\" para que arme una."))
            return
        }
        runScheduled(.linkedInPublish, manual: true, account: account.id)
    }

    public func skipDraft(of accountId: String) {
        guard let account = stores.contentAccounts.find(accountId), stores.contentAccounts.hasDraft(account) else { return }
        skipDraft(account)
    }

    func skipDraft(_ account: ContentAccount) {
        stores.contentAccounts.discardDraft(account, at: Date())
        reply(String(localized: "Listo, no se publica en \(account.title). Escribe \"post \(account.id)\" cuando quieras otra."))
    }
}
