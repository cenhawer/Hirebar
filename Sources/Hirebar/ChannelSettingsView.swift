import AppKit
import HirebarCore
import HirebarDomain
import HirebarEngine
import SwiftUI

final class ChannelSettingsModel: ObservableObject {
    @Published var state: ChannelState = .notConfigured
    @Published var token = ""
    @Published var checking = false
    @Published var problem: String?
    @Published var notificationsAllowed = false
    var onStateChange: (() -> Void)?

    static let botFather = URL(string: "https://t.me/BotFather")

    init() {
        Controller.shared.channel.onChange = { [weak self] state in
            Task { @MainActor in
                self?.state = state
                self?.onStateChange?()
            }
        }
    }

    func reload() {
        state = Controller.shared.channel.state
        Task { @MainActor [weak self] in self?.notificationsAllowed = await MacNotifications.isAllowed() }
    }

    func checkToken() {
        let candidate = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Telegram.looksLikeToken(candidate) else {
            problem = "Ese token no tiene el formato de @BotFather (123456789:AA…). Cópialo completo."
            return
        }
        checking = true
        problem = nil
        Task { @MainActor [weak self] in
            let result = await Controller.shared.channel.useToken(candidate)
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
        }
        reload()
    }

    func startPairing() { Controller.shared.channel.startPairing() }
    func confirm() { Controller.shared.channel.confirm(welcome: Controller.welcome) }
    func decline() { Controller.shared.channel.decline() }
    func changeAccount() { Controller.shared.channel.changeAccount() }
    func sendTest() { Notifier.tell("Aviso de prueba: tu celular ya recibe Hirebar.\n\n" + Controller.shared.statusReport()) }

    func removeBot() {
        Controller.shared.channel.removeBot()
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
        case .notConfigured, .tokenRejected:
            tokenEntry
        case .unlinked(let bot), .expired(let bot):
            if case .expired = model.state {
                Text("No llegó ningún mensaje a tiempo.").foregroundStyle(.secondary)
            }
            Text("Bot @\(bot) listo. Falta anclarlo a tu cuenta de Telegram.")
            Button("Vincular mi cuenta") { model.startPairing() }
                .buttonStyle(.borderedProminent)
        case .waitingForHello(let bot):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Escríbele \"hola\" a @\(bot) desde tu Telegram.")
            }
            Text("Solo cuenta un mensaje de tu chat privado con el bot, enviado desde ahora.")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .confirming(let owner, let bot):
            Text("Le escribió a @\(bot):")
            Text(Self.describe(owner)).font(.headline)
            Text("Si confirmas, el bot solo atenderá a esta cuenta.").font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("Sí, soy yo") { model.confirm() }
                    .buttonStyle(.borderedProminent)
                Button("No soy yo") { model.decline() }
            }
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
