import HirebarDomain
import SwiftUI

struct ExperienceSection: View {
    @Binding var experience: [WorkExperience]

    var body: some View {
        Section {
            ForEach($experience) { $job in
                DisclosureGroup(job.company.isEmpty ? String(localized: "Empleo nuevo") : "\(job.role) · \(job.company)") {
                    TextField("Cargo", text: $job.role)
                    TextField("Empresa", text: $job.company)
                    TextField("Tipo", text: $job.type, prompt: Text("empleo, freelance o contrato"))
                    TextField("Desde (AAAA-MM)", text: $job.from, prompt: Text("2024-01"))
                    TextField("Hasta (AAAA-MM, vacío si sigue)", text: $job.to)
                    AchievementsList(achievements: $job.achievements)
                    Button("Quitar este empleo", role: .destructive) { experience.removeAll { $0.id == job.id } }
                }
            }
            Button("Agregar empleo") { experience.append(WorkExperience()) }
        } header: {
            Text("Experiencia")
        } footer: {
            Text("Cada logro debe ser real y verificable: la IA nunca inventa experiencia ni cifras.")
        }
    }
}

struct AchievementsList: View {
    @Binding var achievements: [Achievement]

    var body: some View {
        ForEach($achievements) { $achievement in
            VStack(alignment: .leading) {
                TextField("Logro", text: $achievement.text, axis: .vertical)
                HStack {
                    TextField("Tecnologías", text: commaList($achievement.tech))
                    TextField("Fecha (AAAA-MM)", text: $achievement.date)
                        .frame(width: 140)
                    Button("Quitar", role: .destructive) { achievements.removeAll { $0.id == achievement.id } }
                }
            }
        }
        Button("Agregar logro") { achievements.append(Achievement()) }
    }
}

struct ResumeVariantsSection: View {
    @Binding var variants: [CVVariantEntry]

    var body: some View {
        Section {
            ForEach($variants) { $variant in
                VStack(alignment: .leading) {
                    HStack {
                        TextField("Identificador", text: $variant.key, prompt: Text("node"))
                        TextField("Nombre", text: $variant.title, prompt: Text("Backend Node.js"))
                    }
                    HStack {
                        TextField("Archivo", text: $variant.file, prompt: Text("HV_Backend_Node"))
                        TextField("Enfoque", text: commaList($variant.focus), prompt: Text("Node.js, NestJS"))
                        Button("Quitar", role: .destructive) { variants.removeAll { $0.id == variant.id } }
                    }
                }
            }
            Button("Agregar hoja de vida") { variants.append(CVVariantEntry()) }
        } header: {
            Text("Hojas de vida")
        } footer: {
            Text("El agente Perfil genera un PDF por cada una con el enfoque que indiques.")
        }
    }
}
