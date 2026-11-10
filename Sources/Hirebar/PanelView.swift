import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import SwiftUI

struct PanelView: View {
    @Bindable var model: PanelModel

    private struct AgentSection: Identifiable {
        let id: String
        let kinds: [AgentKind]
    }

    private let sections = [
        AgentSection(id: String(localized: "Buscar trabajo"), kinds: [.jobs, .freelance]),
        AgentSection(id: String(localized: "Conseguir clientes"), kinds: [.clients, .content]),
        AgentSection(id: String(localized: "Tú"), kinds: [.profile, .analyst]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)
            ForEach(sections) { section in
                Text(section.id)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
                ForEach(model.agents.filter { section.kinds.contains($0.id) }) { agent in
                    AgentRow(agent: agent, model: model)
                }
            }
            Divider()
                .padding(.top, 8)
            footer
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .frame(width: 360)
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hirebar").font(.system(size: 13, weight: .semibold))
                HStack(spacing: 5) {
                    Circle()
                        .fill(model.claudeBusy ? Color.orange : Color.green)
                        .frame(width: 6, height: 6)
                    Text("\(model.aiName) \(model.claude)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button {
                model.editChannel()
            } label: {
                if model.telegramReady {
                    Image(systemName: "paperplane.fill").foregroundStyle(Color.blue)
                } else {
                    Label(model.telegram, systemImage: "paperplane").foregroundStyle(Color.orange)
                }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .help(model.telegram)
        }
    }

    private var footer: some View {
        HStack(spacing: 2) {
            FooterButton(symbol: model.pendingCount > 0 ? "tray.full" : "tray", help: String(localized: "Pendientes de aprobar")) {
                model.openInbox()
            }
            FooterButton(symbol: "doc.text", help: String(localized: "Informes")) { model.open(Paths.reports) }
            FooterButton(symbol: "list.bullet", help: String(localized: "Registro")) { model.openLog() }
            FooterButton(symbol: "folder", help: String(localized: "Carpeta de datos")) { model.open(Paths.root) }
            Spacer()
            Button {
                model.editSettings(nil)
            } label: {
                Label("Ajustes", systemImage: "slider.horizontal.3")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            Menu {
                Button("Ajustes…") { model.editSettings(nil) }
                Button("Cuentas de contenido…") { model.editContentAccounts() }
                Divider()
                Button("Telegram y avisos…") { model.editChannel() }
                Divider()
                Toggle("Abrir al iniciar sesión", isOn: Binding(get: { model.opensAtLogin }, set: { _ in model.toggleLogin() }))
                Divider()
                Button("Salir de Hirebar") { model.onQuit?() }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .padding(.trailing, 4)
        }
    }
}

struct FooterButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .frame(width: 26, height: 22)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(hovering ? 0.08 : 0)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
        .onHover { hovering = $0 }
    }
}

struct AgentRow: View {
    let agent: AgentCardData
    @Bindable var model: PanelModel
    @State private var expanded = false
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: AgentStyle.symbol(agent.id))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(agent.enabled ? AgentStyle.tint(agent.id) : Color.secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(agent.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(agent.enabled ? Color.primary : Color.secondary)
                    Text(agent.purpose)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Text(agent.next)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(agent.working || agent.pauseReason != nil ? Color.orange : Color.secondary)
                    .lineLimit(1)
                    .fixedSize()
                Toggle("", isOn: Binding(get: { agent.enabled }, set: { _ in model.toggleEnabled(agent.id) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.mini)
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 10)
            }
            .contentShape(Rectangle())
            .onTapGesture { expanded.toggle() }

            if expanded {
                details
                    .padding(.leading, 28)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(hovering || expanded ? 0.06 : 0))
        )
        .padding(.horizontal, 4)
        .onHover { hovering = $0 }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let reason = agent.pauseReason {
                HStack(spacing: 8) {
                    Label("En pausa: \(reason)", systemImage: "pause.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("Reanudar") { model.resume(agent.id) }
                        .controlSize(.small)
                }
            }
            Text(agent.status)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
            if !agent.stats.isEmpty {
                Text(agent.stats.joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 12) {
                if agent.canAutoApprove {
                    Toggle("Envío automático", isOn: Binding(get: { agent.autoApprove }, set: { _ in model.toggleAutoApprove(agent.id) }))
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11))
                        .fixedSize()
                }
                Toggle("Práctica", isOn: Binding(get: { agent.practice }, set: { _ in model.togglePractice(agent.id) }))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .fixedSize()
                    .help("Hace todo menos enviar y te cuenta lo que habría hecho")
                Spacer()
                Button(agent.id == .profile ? String(localized: "Regenerar HV") : String(localized: "Correr ahora")) {
                    model.runNow(agent.id)
                }
                .controlSize(.small)
                .disabled(!agent.enabled)
                Menu {
                    if !agent.sources.isEmpty {
                        Section("Portales") {
                            ForEach(agent.sources) { source in
                                Toggle(source.title, isOn: Binding(get: { source.on }, set: { _ in model.toggleSource(source.id) }))
                            }
                        }
                    }
                    if !agent.schedule.isEmpty {
                        Section("Horario") {
                            ForEach(agent.schedule, id: \.self) { line in Text(line) }
                        }
                    }
                    if agent.id == .content {
                        Button("Cuentas de contenido…") { model.editContentAccounts() }
                    }
                    Button("Ajustes de \(agent.name)…") { model.editSettings(agent.id) }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
    }
}
