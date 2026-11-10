import AppKit
import HirebarApplication
import HirebarDomain
import SwiftUI

@Observable
final class InboxModel {
    private let engine: Engine
    var lists: [InboxList] = []
    var drafts: [InboxDraft] = []
    var selection = InboxSelection()
    var onChange: (() -> Void)?

    init(engine: Engine) {
        self.engine = engine
    }

    var isEmpty: Bool { lists.isEmpty && drafts.isEmpty }
    var pendingCount: Int { lists.count + drafts.count }

    func reload() {
        lists = engine.controller.pendingLists()
        drafts = engine.controller.pendingDrafts()
    }

    func approveSelected(_ list: InboxList) {
        guard let picks = selection.picks(for: list) else { return }
        engine.controller.approveList(list.id, picks: picks)
        finish(list)
    }

    func approveAll(_ list: InboxList) {
        engine.controller.approveList(list.id, picks: [])
        finish(list)
    }

    func discard(_ list: InboxList) {
        engine.controller.discardPendingList(list.id)
        finish(list)
    }

    func publish(_ draft: InboxDraft) {
        engine.controller.publishDraft(of: draft.id)
        reload()
        onChange?()
    }

    func skip(_ draft: InboxDraft) {
        engine.controller.skipDraft(of: draft.id)
        reload()
        onChange?()
    }

    func open(_ target: String) {
        guard let url = URL(string: target), url.scheme?.hasPrefix("http") == true else { return }
        NSWorkspace.shared.open(url)
    }

    private func finish(_ list: InboxList) {
        selection.clear(list.id)
        reload()
        onChange?()
    }
}

final class InboxWindowController {
    let model: InboxModel
    private var window: NSWindow?

    init(engine: Engine) {
        model = InboxModel(engine: engine)
    }

    func show() {
        model.reload()
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: InboxView(model: model)))
            window.title = String(localized: "Pendientes de aprobar")
            window.setContentSize(NSSize(width: 720, height: 560))
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
