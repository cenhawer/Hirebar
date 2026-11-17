import AppKit
import HirebarApplication
import HirebarDomain
import SwiftUI

@Observable
final class ActivityModel {
    let repository: ActivityRepository
    let agents: AgentRepository
    private var all: [ActivityEntry] = []
    private var names: [String: String] = [:]
    private(set) var entries: [ActivityEntry] = []
    private var filter = ActivityFilter()

    init(repository: ActivityRepository, agents: AgentRepository) {
        self.repository = repository
        self.agents = agents
    }

    var agent: AgentKind? {
        get { filter.agent.flatMap { AgentKind(rawValue: $0.rawValue) } }
        set {
            filter.agent = newValue.map { AgentID(rawValue: $0.rawValue) }
            apply()
        }
    }

    var period: ActivityPeriod {
        get { filter.period }
        set {
            filter.period = newValue
            apply()
        }
    }

    func reload() {
        names = Dictionary(uniqueKeysWithValues: AgentKind.allCases.map { ($0.rawValue, agents.load($0).name) })
        all = repository.activity()
        apply()
    }

    func apply() {
        entries = filter.apply(all, now: Date())
    }

    func name(of kind: AgentKind) -> String { names[kind.rawValue] ?? kind.rawValue }

    func agentName(_ id: AgentID) -> String { names[id.rawValue] ?? id.rawValue }
}

final class ActivityWindowController {
    private let model: ActivityModel
    private var window: NSWindow?

    init(engine: Engine) {
        model = ActivityModel(repository: engine.activity, agents: engine.controller.stores.agents)
    }

    func show() {
        model.reload()
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: ActivityView(model: model)))
            window.title = String(localized: "Actividad de Hirebar")
            window.setContentSize(NSSize(width: 720, height: 520))
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct ActivityView: View {
    @Bindable var model: ActivityModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Picker("Agente", selection: $model.agent) {
                    Text("Todos").tag(AgentKind?.none)
                    ForEach(AgentKind.allCases, id: \.self) { kind in
                        Text(model.name(of: kind)).tag(AgentKind?.some(kind))
                    }
                }
                .frame(maxWidth: 220)
                Picker("Período", selection: $model.period) {
                    ForEach(ActivityPeriod.allCases, id: \.self) { period in
                        Text(period.title).tag(period)
                    }
                }
                .frame(maxWidth: 240)
                Spacer()
                Button("Actualizar") { model.reload() }
            }
            .padding()
            if model.entries.isEmpty {
                ContentUnavailableView(
                    "Sin actividad", systemImage: "tray",
                    description: Text("Aquí aparece cada envío: qué se hizo, a quién, cuándo y con qué texto."))
            } else {
                List(model.entries) { entry in
                    ActivityRow(entry: entry, agentName: model.agentName(entry.agent))
                }
            }
        }
    }
}

struct ActivityRow: View {
    let entry: ActivityEntry
    let agentName: String

    var symbol: String {
        switch entry.outcome {
        case .sent: return "checkmark.circle"
        case .rejected: return "exclamationmark.triangle"
        case .practice: return "eye"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.action.activityTitle).font(.headline)
                Text(agentName).foregroundStyle(.secondary)
                Spacer()
                Text(entry.at, format: .dateTime.day().month().hour().minute()).foregroundStyle(.secondary)
            }
            Text(entry.target.displayText).textSelection(.enabled)
            Label(entry.outcome.title, systemImage: symbol).font(.caption)
            if let text = entry.text, !text.isEmpty {
                DisclosureGroup("Texto enviado") {
                    Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
