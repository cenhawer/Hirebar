import AppKit
import HirebarAI
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import SwiftUI

struct EngineEditor: View {
    @Bindable var model: SettingsModel

    static let customWarning =
        String(localized: "Hirebar no puede verificar qué permisos tienen estos comandos. El de lectura no debería poder enviar, ")
        + String(localized: "publicar ni escribir fuera de la carpeta de trabajo. Igual, cada acción que reporte el de ejecución ")
        + String(localized: "se compara con lo que aprobaste.")
    static let variablesFooter =
        String(localized: "Se ejecutan en una terminal con estas variables:\n") + AIEngineSettings.variablesHelp
        + String(localized: "\nLo que imprima es la respuesta que te llega a Telegram.")
    static let presetFooter =
        String(localized: "Con esta IA, las tareas que leen con el navegador (redes, tus portales, seguimientos, clientes y revisión ")
        + String(localized: "de rendimiento) no corren: solo Claude Code puede leer con el navegador sin poder actuar. Si tu versión ")
        + String(localized: "usa otras opciones, elige \"Otra IA\" y copia estos comandos para ajustarlos.")

    var body: some View {
        Form {
            Section {
                Picker("IA", selection: $model.engine.kind) {
                    ForEach(AIEngineKind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.radioGroup)
                Text(model.engine.kind.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Qué IA hace el trabajo")
            } footer: {
                Text(
                    String(
                        localized: """
                            La búsqueda en los portales incluidos no usa IA. La IA se usa para enviar propuestas, postular,\u{20}
                            """)
                        + String(localized: "hacer seguimientos, escribir correos y publicaciones, y actualizar tu perfil.")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if model.engine.kind == .custom {
                Section {
                    TextField(
                        String(localized: "Comando de lectura y redacción"),
                        text: $model.engine.readCommand,
                        prompt: Text("mi-ia --solo-lectura --prompt \"$HIREBAR_FULL_PROMPT\""),
                        axis: .vertical
                    )
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(2...5)
                    TextField(
                        String(localized: "Comando de ejecución"),
                        text: $model.engine.actCommand,
                        prompt: Text("mi-ia --prompt \"$HIREBAR_FULL_PROMPT\""),
                        axis: .vertical
                    )
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(2...5)
                    Label(Self.customWarning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text("Comandos de tu IA")
                } footer: {
                    Text(Self.variablesFooter)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let commands = EngineCommands.phases(for: model.engine.kind) {
                Section {
                    LabeledContent("Lectura") {
                        Text(commands.read).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    }
                    LabeledContent("Ejecución") {
                        Text(commands.act).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    }
                } header: {
                    Text("Comandos que se usan")
                } footer: {
                    Text(Self.presetFooter)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    Button(model.checkingEngine ? String(localized: "Probando…") : String(localized: "Probar")) { model.checkEngine() }
                        .disabled(model.checkingEngine)
                    if let text = model.engineCheck {
                        Label(text, systemImage: model.engineCheckOK ? "checkmark.circle.fill" : "info.circle")
                            .font(.caption)
                            .foregroundStyle(model.engineCheckOK ? Color.green : Color.secondary)
                    }
                }
            } footer: {
                Text("Prueba la IA elegida con una pregunta corta, antes o después de guardar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
