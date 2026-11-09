import AppKit
import HirebarApplication
import HirebarDomain
import HirebarEngine
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import SwiftUI

final class ChannelSettingsModel: ObservableObject {
    @Published var state: ChannelState = .notConfigured
    @Published var token = ""
    @Published var checking = false
    @Published var problem: String?
    @Published var notificationsAllowed = false
    var onStateChange: (() -> Void)?

    static let botFather = URL(string: "https://t.me/BotFather")

    let engine: Engine

    init(engine: Engine) {
        self.engine = engine
        engine.controller.channel.onChange = { [weak self] state in
            Task { @MainActor in
                self?.state = state
                self?.onStateChange?()
            }
        }
    }

    func reload() {
        state = engine.controller.channel.state
        Task { @MainActor [weak self] in self?.notificationsAllowed = await MacNotifications.isAllowed() }
    }

    func checkToken() {
        guard !checking else { return }
        let candidate = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Telegram.looksLikeToken(candidate) else {
            problem = "Ese token no tiene el formato de @BotFather (123456789:AA…). Cópialo completo."
            return
        }
        checking = true
        problem = nil
        Task { @MainActor [weak self] in
            let result = await engine.controller.channel.useToken(candidate)
            self?.finishCheck(result)
        }
    }

    func finishCheck(_ result: BotCheck) {
        checking = false
        switch result {
        case .valid:
            token = ""
        case .rejected:
            problem = "Telegram no reconoce ese token. Revísalo en @BotFather (/mybots → tu bot → API Token)."
        case .unreachable:
            problem = "No pude hablar con Telegram. Revisa la conexión a internet y vuelve a intentar."
        case .notSaved:
            problem = "No pude guardar el token en el Llavero de macOS. Revisa que el Llavero esté desbloqueado y vuelve a intentar."
        }
        reload()
    }

    func startPairing() { engine.controller.channel.startPairing() }
    func confirm() { engine.controller.channel.confirm(welcome: Controller.welcome) }
    func decline() { engine.controller.channel.decline() }
    func changeAccount() { engine.controller.channel.changeAccount() }
    func cancelPairing() { engine.controller.channel.cancelPairing() }
    func sendTest() { engine.controller.sendTestMessage() }

    func removeBot() {
        if engine.controller.channel.removeBot() == .keychainFailed {
            problem = "No pude borrar el token del Llavero de macOS. Revisa que el Llavero esté desbloqueado y vuelve a intentar."
        }
        reload()
    }

    func requestNotifications() {
        Task { @MainActor [weak self] in
            let allowed = await MacNotifications.requestPermission()
            self?.notificationsAllowed = allowed
            if !allowed, let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func openBotFather() {
        if let url = Self.botFather { NSWorkspace.shared.open(url) }
    }
}

struct ChannelSettingsView: View {
    @ObservedObject var model: ChannelSettingsModel

    var body: some View {
        Form {
            Section("Telegram") {
                telegram
                if let problem = model.problem {
                    Label(problem, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            Section("Avisos en la Mac") {
                LabeledContent("Notificaciones") {
                    Text(model.notificationsAllowed ? "Permitidas" : "Sin permiso")
                        .foregroundStyle(model.notificationsAllowed ? Color.secondary : Color.orange)
                }
                Text(Self.fallbackExplanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if !model.notificationsAllowed {
                    Button("Permitir notificaciones") { model.requestNotifications() }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { model.reload() }
    }

    @ViewBuilder
    private var telegram: some View {
        switch model.state {
        case .misconfigured:
            Label(Self.misconfiguredText, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .notConfigured, .tokenRejected:
            tokenEntry
        case .unlinked(let bot), .expired(let bot):
            if case .expired = model.state {
                Text("No llegó ningún mensaje a tiempo.").foregroundStyle(.secondary)
            }
            Text("Bot @\(bot) listo. Falta anclarlo a tu cuenta de Telegram.")
            HStack {
                Button("Vincular mi cuenta") { model.startPairing() }
                    .buttonStyle(.borderedProminent)
                Spacer()
                Button("Usar otro token", role: .destructive) { model.removeBot() }
            }
        case .waitingForHello(let bot):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Escríbele \"hola\" a @\(bot) desde tu Telegram.")
            }
            Text("Solo cuenta un mensaje de texto de tu chat privado con el bot, enviado desde ahora.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Button("Cancelar") { model.cancelPairing() }
                Spacer()
                Button("Usar otro token", role: .destructive) { model.removeBot() }
            }
        case .confirming(let candidate, let bot):
            confirmation(candidate, bot: bot)
        case .connected(let owner, let bot):
            LabeledContent("Conectado como") { Text(Self.describe(owner)) }
            if !bot.isEmpty { LabeledContent("Bot") { Text("@\(bot)") } }
            HStack {
                Button("Enviar aviso de prueba") { model.sendTest() }
                Button("Cambiar de cuenta") { model.changeAccount() }
                Spacer()
                Button("Quitar bot", role: .destructive) { model.removeBot() }
            }
        }
    }

    @ViewBuilder
    private func confirmation(_ candidate: PairingCandidate, bot: String) -> some View {
        Text("Le escribió a @\(bot):")
        Text(Self.describe(candidate.owner)).font(.headline)
        LabeledContent("ID de Telegram") { Text(String(candidate.owner.userId)).textSelection(.enabled) }
        LabeledContent("Mensaje") { Text("\"\(candidate.text)\"") }
        if !candidate.hasUsername {
            Label(Self.noUsernameWarning, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
        Text("Confirma solo si el mensaje es el que acabas de escribir. El bot atenderá únicamente a esta cuenta.")
            .font(.callout)
            .foregroundStyle(.secondary)
        HStack {
            Button("Sí, soy yo") { model.confirm() }
                .buttonStyle(.borderedProminent)
            Button("No soy yo") { model.decline() }
            Spacer()
            Button("Cancelar") { model.cancelPairing() }
        }
    }

    private var tokenEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            if case .tokenRejected = model.state {
                Label("Telegram ya no acepta el token guardado. Pega uno nuevo.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            Text("1. En Telegram abre @BotFather, envía /newbot y ponle un nombre.\n2. Copia el token que te entrega y pégalo aquí.")
                .font(.callout)
            Button("Abrir @BotFather") { model.openBotFather() }
            HStack {
                SecureField("123456789:AA…", text: $model.token)
                    .onSubmit { model.checkToken() }
                Button("Comprobar") { model.checkToken() }
                    .disabled(model.checking || model.token.isEmpty)
                if model.checking { ProgressView().controlSize(.small) }
            }
        }
    }

    static let misconfiguredText =
        "Faltan los ajustes del canal dentro de la app (canal.json). Vuelve a instalarla con scripts/bundle.sh --install."
    static let noUsernameWarning =
        "Esta cuenta no tiene usuario de Telegram, así que el nombre se puede copiar: revisa que el mensaje sea el tuyo."
    static let fallbackExplanation =
        "Si Telegram no está configurado o un mensaje no llega, el aviso aparece como notificación y al tocarlo se abre el panel."

    static func describe(_ owner: ChannelOwner) -> String {
        let name = owner.name.isEmpty ? "Tu cuenta" : owner.name
        return owner.username.map { "\(name) (@\($0))" } ?? name
    }
}

enum ChannelStatusText {
    static func describe(_ state: ChannelState) -> String {
        switch state {
        case .misconfigured: return "Falta reinstalar la app"
        case .notConfigured: return "Telegram sin configurar"
        case .tokenRejected: return "El token ya no sirve"
        case .unlinked, .expired: return "Falta vincular tu cuenta"
        case .waitingForHello: return "Esperando tu hola"
        case .confirming: return "Confirma tu cuenta en Ajustes"
        case .connected(let owner, _):
            return owner.name.isEmpty ? "Telegram conectado" : "Conectado como \(owner.name)"
        }
    }

    static func isReady(_ state: ChannelState) -> Bool {
        if case .connected = state { return true }
        return false
    }
}
