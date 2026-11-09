import AppKit
import HirebarDomain
import HirebarEngine
import HirebarMedia
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import SwiftUI

/// Ajustes → Cuentas de contenido: una sección por cuenta (empresa, personal…), cada una con su red, nombre, días y paleta.
struct ContentAccountsEditor: View {
    @Binding var accounts: [EditableAccount]

    var body: some View {
        Form {
            Section {
                Text("Cada cuenta recibe sus propias publicaciones con imágenes, con su nombre y sus colores. Por ejemplo, una para tu empresa en Instagram y otra para ti en LinkedIn. En Telegram: \"post <identificador>\" y \"publica <identificador>\".")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    accounts.append(EditableAccount(account: ContentAccount(id: "cuenta-\(accounts.count + 1)")))
                } label: {
                    Label("Agregar cuenta", systemImage: "plus")
                }
            }
            ForEach($accounts) { $item in
                ContentAccountSection(account: $item.account, canRemove: accounts.count > 1) {
                    accounts.removeAll { $0.id == item.id }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ContentAccountSection: View {
    @Binding var account: ContentAccount
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        Section {
            Toggle("Prendida", isOn: $account.enabled)
            Picker("Red", selection: $account.network) {
                ForEach(ContentNetwork.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            TextField("Identificador (para Telegram)", text: $account.id, prompt: Text("empresa"))
            TextField("Nombre en las imágenes", text: $account.name, prompt: Text("Mi Empresa"))
            TextField("Línea bajo el nombre", text: $account.tagline, prompt: Text("Software a medida · Backend y nube"))
            TextField("Usuario", text: $account.handle, prompt: Text("@mi_empresa"))
            TextField("De qué habla y para quién", text: $account.focus, axis: .vertical)
                .lineLimit(2...5)
            LabeledContent("Días") { DaysPicker(days: $account.days) }
            Toggle("También un video corto (Reel o Short) narrado con tu voz", isOn: $account.video)
            if account.video {
                FfmpegRequirement()
                Toggle("Subtítulos palabra por palabra", isOn: $account.captions)
                Text("Te llega una vista previa sin voz y el guion. Respondes en Telegram con una nota de voz leyéndolo y Hirebar te devuelve el video con tu voz, cuadrado escena por escena. Música de fondo (opcional): pon un archivo musica.mp3 en la carpeta de la cuenta (workspace/contenido/\(account.id)/).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Paleta", selection: preset) {
                Text("Personalizada").tag("")
                ForEach(PalettePreset.all) { Text($0.title).tag($0.id) }
            }
            ColorField(title: "Fondo", hex: $account.palette.background)
            ColorField(title: "Tarjetas y bloques", hex: $account.palette.surface)
            ColorField(title: "Acento", hex: $account.palette.accent)
            ColorField(title: "Texto", hex: $account.palette.text)
            ColorField(title: "Texto secundario", hex: $account.palette.muted)
            TextField("Estilo de las imágenes", text: $account.style, axis: .vertical)
                .lineLimit(2...5)
            PalettePreview(account: account)

            if canRemove {
                Button("Quitar esta cuenta", role: .destructive, action: onRemove)
            }
        } header: {
            Label(account.title, systemImage: account.network == .instagram ? "camera" : "person.crop.rectangle")
        } footer: {
            Text("La IA usa estos colores y este estilo en cada imagen. Al escoger una paleta se llenan los colores y el estilo; después puedes cambiarlos. Con el video prendido llega también un video vertical de 15 a 30 segundos.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var preset: Binding<String> {
        Binding(
            get: { PalettePreset.all.first { $0.palette == account.palette }?.id ?? "" },
            set: { id in
                guard let chosen = PalettePreset.all.first(where: { $0.id == id }) else { return }
                account.palette = chosen.palette
                account.style = chosen.style
            })
    }
}

struct DaysPicker: View {
    @Binding var days: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TaskEditor.days) { day in
                Toggle(day.title, isOn: binding(day.id))
                    .toggleStyle(.button)
                    .controlSize(.small)
            }
        }
    }

    private var selected: Set<String> {
        let names = Set(days.map { TextTools.normalize($0).trimmingCharacters(in: .whitespaces) })
        if names.contains("todos") { return Set(TaskEditor.days.map(\.id)) }
        if names.contains("habiles") { return TaskEditor.workdays.union(names.subtracting(["habiles"])) }
        return names
    }

    private func binding(_ key: String) -> Binding<Bool> {
        Binding(get: { selected.contains(key) }, set: { on in
            var chosen = selected
            if on { chosen.insert(key) } else { chosen.remove(key) }
            days = chosen.count == 7 ? ["todos"] : TaskEditor.days.map(\.id).filter { chosen.contains($0) }
        })
    }
}

struct ColorField: View {
    let title: String
    @Binding var hex: String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                TextField("", text: $hex, prompt: Text("#000000"))
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 90)
                ColorPicker("", selection: color, supportsOpacity: false)
                    .labelsHidden()
            }
        }
    }

    private var color: Binding<Color> {
        Binding(get: { Color(hex: hex) }, set: { hex = $0.hexString })
    }
}

struct PalettePreview: View {
    let account: ContentAccount

    var body: some View {
        let p = account.palette
        VStack(alignment: .leading, spacing: 8) {
            Text("ASÍ SE VEN")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: p.accent))
                .foregroundColor(Color(hex: p.background))
            (Text("Tus imágenes, ").foregroundColor(Color(hex: p.text))
             + Text("con tus colores").foregroundColor(Color(hex: p.accent)).italic())
                .font(.system(size: 22, weight: .bold))
            HStack {
                Text(account.name.isEmpty ? "Tu nombre" : account.name)
                Spacer()
                Text("1/5")
            }
            .font(.caption)
            .foregroundColor(Color(hex: p.muted))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(Color(hex: p.background))
                .overlay(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 6).fill(Color(hex: p.surface))
                        .frame(width: 70, height: 40)
                        .padding(12)
                }
        )
    }
}

extension Color {
    static func isHex(_ text: String) -> Bool {
        text.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
    }

    init(hex: String) {
        let clean = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        let value = UInt32(clean, radix: 16) ?? 0
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255,
                  opacity: 1)
    }

    var hexString: String {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
    }
}

struct FfmpegRequirement: View {
    @State private var status = ToolCheck.status()

    var body: some View {
        if let status, !status.ffmpegFound {
            VStack(alignment: .leading, spacing: 6) {
                Label("Para el video con tu voz falta ffmpeg en el Mac.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                HStack {
                    Text(status.installCommand).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                    Button("Copiar") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(status.installCommand, forType: .string)
                    }
                    Button("Comprobar de nuevo") { self.status = ToolCheck.status() }
                }
            }
        } else if status == nil {
            Label("Falta herramientas.json dentro de la app; vuelve a instalarla.", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}
