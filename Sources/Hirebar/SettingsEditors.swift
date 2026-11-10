import AppKit
import HirebarAI
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import SwiftUI

struct TaskEditor: View {
    @Binding var task: AgentTask
    @State private var hoursText = ""

    static let days = [
        DayOption(id: "lun", title: "L"), DayOption(id: "mar", title: "M"), DayOption(id: "mie", title: "X"),
        DayOption(id: "jue", title: "J"), DayOption(id: "vie", title: "V"), DayOption(id: "sab", title: "S"),
        DayOption(id: "dom", title: "D"),
    ]
    static let workdays: Set<String> = ["lun", "mar", "mie", "jue", "vie"]

    var body: some View {
        Section {
            if task.mode == .linkedInDraft {
                LabeledContent("Días", value: "los de cada cuenta (Contenido → Cuentas de contenido)")
            } else {
                LabeledContent("Días") {
                    HStack(spacing: 4) {
                        ForEach(Self.days) { day in
                            Toggle(day.title, isOn: dayBinding(day.id))
                                .toggleStyle(.button)
                                .controlSize(.small)
                        }
                    }
                }
            }
            TextField("Horas (0 a 23, separadas por coma)", text: $hoursText, prompt: Text("8, 14"))
                .onAppear { hoursText = task.hours.sorted().map(String.init).joined(separator: ", ") }
                .onChange(of: hoursText) { _, text in
                    task.hours = text.split(whereSeparator: { $0 == "," || $0 == " " })
                        .compactMap { Int($0) }
                        .filter { (0...23).contains($0) }
                }
            Stepper(value: $task.windowHours, in: 1...48) {
                LabeledContent("Si el Mac estaba dormido, puede correr hasta", value: "\(task.windowHours) h después")
            }
        } header: {
            Text(task.mode.title)
        } footer: {
            Text(task.hours.isEmpty ? "Sin horas: esta tarea no corre sola." : "Corre \(task.scheduleText).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var selectedDays: Set<String> {
        let names = Set(task.days.map { TextTools.normalize($0).trimmingCharacters(in: .whitespaces) })
        if names.contains("todos") { return Set(Self.days.map(\.id)) }
        if names.contains("habiles") { return Self.workdays.union(names.subtracting(["habiles"])) }
        return names
    }

    private func dayBinding(_ key: String) -> Binding<Bool> {
        Binding(
            get: { selectedDays.contains(key) },
            set: { on in
                var days = selectedDays
                if on { days.insert(key) } else { days.remove(key) }
                if days.count == 7 {
                    task.days = ["todos"]
                } else if days == Self.workdays {
                    task.days = ["habiles"]
                } else {
                    task.days = Self.days.map(\.id).filter { days.contains($0) }
                }
            })
    }
}

struct SkillsEditor: View {
    @Binding var skills: [EditableSkill]

    var body: some View {
        Form {
            Section {
                ForEach($skills) { $item in
                    SkillRow(skill: $item.skill) {
                        let id = item.id
                        skills.removeAll { $0.id == id }
                    }
                }
                Button("Agregar habilidad") {
                    skills.append(EditableSkill(skill: Skill(name: "", level: .familiar)))
                }
            } header: {
                Text("Habilidades")
            } footer: {
                Text(
                    "Domino: se busca y cuenta como ENCAJA. Conozco: se busca como RETO. Evito: se descarta. "
                        + "Los otros nombres sirven para reconocerla en los avisos (por ejemplo, Node.js: node, nodejs)."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct SkillRow: View {
    @Binding var skill: Skill
    let onDelete: () -> Void
    @State private var aliasesText = ""

    var body: some View {
        HStack(spacing: 8) {
            TextField("Nombre", text: $skill.name, prompt: Text("Node.js"))
                .frame(width: 150)
            Picker("Nivel", selection: $skill.level) {
                ForEach(SkillLevel.allCases, id: \.self) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 210)
            TextField("Otros nombres", text: $aliasesText, prompt: Text("node, nodejs"))
                .onAppear { aliasesText = skill.aliases.joined(separator: ", ") }
                .onChange(of: aliasesText) { _, text in
                    skill.aliases = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                }
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .labelsHidden()
    }
}

struct CustomPortalsSection: View {
    @Binding var portals: [CustomPortal]
    let onAdd: () -> Void

    var body: some View {
        Section {
            ForEach($portals) { $portal in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Toggle("", isOn: $portal.enabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                        TextField("Nombre", text: $portal.name, prompt: Text("Torre"))
                            .frame(width: 140)
                        TextField("Enlace de búsqueda", text: $portal.url, prompt: Text("https://torre.ai/search/jobs?q=backend"))
                        Button {
                            let id = portal.id
                            portals.removeAll { $0.id == id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Quitar este portal")
                    }
                    TextField(
                        "Indicaciones (opcional)", text: $portal.notes,
                        prompt: Text("Ej.: filtra por remoto y Colombia; ignora las de inglés")
                    )
                    .font(.caption)
                    if !portal.isValid {
                        Text("Falta el nombre o un enlace que empiece por https://")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .labelsHidden()
                .padding(.vertical, 2)
            }
            Button("Agregar portal", action: onAdd)
        } header: {
            Text("Tus portales")
        } footer: {
            Text(
                "Pega el enlace de una búsqueda ya filtrada en el portal que quieras. La IA lo revisa con tu Chrome "
                    + "(sirve aunque pida sesión iniciada) a las horas de la tarea \"Revisar tus portales\" "
                    + "y te manda lo que encuentre en la lista de siempre."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
