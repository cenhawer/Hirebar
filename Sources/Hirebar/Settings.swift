import AppKit
import HirebarAI
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsModel
    @Bindable var channel: ChannelSettingsModel

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $model.selection) {
                Section("Agentes") {
                    ForEach(AgentKind.allCases, id: \.self) { kind in
                        Label(
                            model.agents.first(where: { $0.id == kind })?.name ?? kind.rawValue,
                            systemImage: AgentStyle.symbol(kind)
                        )
                        .tag(SettingsPage.agent(kind))
                    }
                }
                Section("Perfil") {
                    Label("Habilidades", systemImage: "star.fill")
                        .tag(SettingsPage.skills)
                }
                Section("Contenido") {
                    Label("Cuentas de contenido", systemImage: "photo.on.rectangle.angled")
                        .tag(SettingsPage.content)
                }
                Section("General") {
                    Label("Motor de IA", systemImage: "cpu")
                        .tag(SettingsPage.engine)
                    Label("Telegram y avisos", systemImage: "paperplane")
                        .tag(SettingsPage.channel)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 210)
            Divider()
            VStack(spacing: 0) {
                content
                Divider()
                footer
            }
        }
        .frame(minWidth: 760, minHeight: 500)
    }

    @ViewBuilder
    private var content: some View {
        switch model.selection {
        case .agent(let kind):
            if let agent = model.agentBinding(kind) {
                AgentEditor(agent: agent, model: model)
                    .id(kind)
            }
        case .skills:
            SkillsEditor(skills: $model.skills)
        case .content:
            ContentAccountsEditor(accounts: $model.contentAccounts)
        case .engine:
            EngineEditor(model: model)
        case .channel:
            ChannelSettingsView(model: channel)
        case nil:
            Text("Elige un agente a la izquierda.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Mostrar archivo") { model.revealFile() }
            Spacer()
            if let message = model.message {
                Text(message).foregroundStyle(.secondary).lineLimit(2).truncationMode(.middle)
            }
            Button("Descartar") { model.reload() }
            Button("Guardar") { model.save() }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
    }
}

struct AgentEditor: View {
    @Binding var agent: AgentSettings
    @Bindable var model: SettingsModel

    private var sourceIDs: [String] {
        switch agent.id {
        case .jobs: return Config.jobSources
        case .freelance: return Config.freelanceSources
        default: return []
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("Nombre", text: $agent.name)
                TextField("Descripción", text: $agent.purpose, axis: .vertical)
                    .lineLimit(2...4)
                Toggle("Prendido", isOn: $agent.enabled)
                if [.jobs, .freelance, .clients].contains(agent.id) {
                    Toggle("Envío automático (sin esperar tu \"si\" en Telegram)", isOn: $agent.autoApprove)
                }
                Toggle("Modo práctica (hace todo menos enviar y te cuenta lo que habría hecho)", isOn: $agent.practice)
            } header: {
                Label(agent.name, systemImage: AgentStyle.symbol(agent.id))
            }

            if agent.hasSearch {
                Section {
                    Stepper(value: minutes, in: 15...240, step: 5) {
                        LabeledContent("Buscar cada", value: "\(minutes.wrappedValue) min")
                    }
                    ForEach(sourceIDs, id: \.self) { source in
                        Toggle(StatusMenu.sourceTitles[source] ?? source, isOn: model.sourceBinding(source))
                    }
                } header: {
                    Text("Portales incluidos")
                } footer: {
                    Text("Se revisan solos, sin usar IA: leen las páginas públicas y te avisan lo que encaja con tu perfil.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                CustomPortalsSection(portals: model.portalsBinding(agent.id)) {
                    model.addPortal(agent.id)
                }
            }

            if [.jobs, .freelance, .clients].contains(agent.id) {
                Section {
                    Stepper(value: limit, in: 0...100) {
                        LabeledContent("Cupo diario", value: limit.wrappedValue == 0 ? "sin límite" : "\(limit.wrappedValue)")
                    }
                } footer: {
                    Text("Se le indica a la IA como máximo de envíos por día para este agente.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if agent.id == .content {
                Section {
                    Button("Configurar cuentas de contenido…") { model.selection = .content }
                } footer: {
                    Text("Nombre, red, días y colores de cada cuenta (por ejemplo, la de tu empresa y la personal).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(agent.tasks.indices, id: \.self) { index in
                TaskEditor(task: $agent.tasks[index])
            }

            if agent.tasks.isEmpty && !agent.hasSearch {
                Section {
                    Text(
                        agent.id == .profile
                            ? "Corre cuando se lo pides: \"logro\", \"trabajo\" o \"hv\" en Telegram, o Regenerar HV en el panel."
                            : "Este agente no tiene tareas programadas."
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var minutes: Binding<Int> {
        Binding(get: { agent.searchEveryMinutes ?? 30 }, set: { agent.searchEveryMinutes = $0 })
    }

    private var limit: Binding<Int> {
        Binding(get: { agent.dailyLimit ?? 0 }, set: { agent.dailyLimit = $0 == 0 ? nil : $0 })
    }
}
