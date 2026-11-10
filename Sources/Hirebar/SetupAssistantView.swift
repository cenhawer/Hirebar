import HirebarApplication
import HirebarDomain
import SwiftUI

struct SetupAssistantView: View {
    @Bindable var model: SetupAssistantModel
    @Bindable var channel: ChannelSettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Paso \(model.page.rawValue + 1) de \(SetupAssistantModel.Page.allCases.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(title).font(.title2.weight(.semibold))
            content
            Spacer(minLength: 0)
            HStack {
                Button("Atrás") { model.back() }
                    .disabled(model.page == .welcome)
                Spacer()
                if model.page == .done {
                    Button("Terminar") { model.finish() }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Seguir") { model.next() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 620, height: 560, alignment: .topLeading)
    }

    private var title: LocalizedStringKey {
        switch model.page {
        case .welcome: return "Te damos la bienvenida a Hirebar"
        case .engine: return "Motor de IA"
        case .channel: return "Telegram"
        case .agents: return "Agentes"
        case .permissions: return "Permisos de macOS"
        case .done: return "Resumen"
        }
    }

    @ViewBuilder private var content: some View {
        switch model.page {
        case .welcome: welcome
        case .engine: engineStep
        case .channel: ChannelSettingsView(model: channel)
        case .agents: agentsStep
        case .permissions: permissionsStep
        case .done: SetupChecklistList(pending: model.pending, emptyText: "Todo listo: Hirebar ya puede trabajar.")
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("En unos pasos dejas listo tu nombre, la IA que hace el trabajo, Telegram y los agentes. Nada se envía sin tu aprobación.")
                .fixedSize(horizontal: false, vertical: true)
            TextField("Tu nombre", text: $model.ownerName, prompt: Text("Ana Gómez"))
                .textFieldStyle(.roundedBorder)
            Text("Firma los correos, las propuestas y las publicaciones.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var engineStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("IA", selection: Binding(get: { model.engineKind }, set: { model.chooseEngine($0) })) {
                ForEach(AIEngineKind.allCases, id: \.self) { kind in Text(kind.title).tag(kind) }
            }
            Text(model.engineKind.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.engineKind == .custom {
                Text("Escribe los comandos de tu IA en Ajustes → Motor de IA y vuelve a probar.")
                    .font(.caption)
            }
            HStack {
                Button(model.checkingEngine ? String(localized: "Probando…") : String(localized: "Probar")) { model.checkEngine() }
                    .disabled(model.checkingEngine)
                if model.engineOK { Label("Probada", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
            }
            if let result = model.engineResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(model.engineOK ? Color.secondary : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var agentsStep: some View {
        List(model.agents, id: \.id) { agent in
            Toggle(isOn: Binding(get: { agent.enabled }, set: { model.setAgent(agent.id, enabled: $0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                    Text(agent.purpose).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            PermissionRow(
                title: "Reconocimiento de voz", detail: "Hace falta para armar el video con tu nota de voz.", state: model.voice
            ) { model.request(.voiceRecognition) }
            PermissionRow(
                title: "Notificaciones", detail: "Avisan en la Mac cuando Telegram no está disponible.", state: model.notifications
            ) { model.request(.notifications) }
            Text("Si negaste un permiso, actívalo en Ajustes del Sistema → Privacidad y seguridad.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct PermissionRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let state: PermissionState
    let request: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            switch state {
            case .allowed: Label("Permitido", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .denied: Label("Negado", systemImage: "xmark.circle").foregroundStyle(.orange)
            case .undecided: Button("Permitir", action: request)
            }
        }
    }
}
