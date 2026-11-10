import HirebarDomain
import SwiftUI

struct ProfileEditorView: View {
    @Binding var document: ProfileDocument

    var body: some View {
        Form {
            Section("Datos personales") {
                TextField("Nombre", text: $document.person.name)
                TextField("Titular", text: $document.person.headline, prompt: Text("Desarrollador Backend Senior"))
                TextField("Ciudad", text: $document.person.city)
                TextField("País", text: $document.person.country)
                TextField("Correo", text: $document.person.email)
                TextField("Teléfono", text: $document.person.phone)
                TextField("LinkedIn", text: $document.person.linkedin)
                TextField("GitHub", text: $document.person.github)
                TextField("Portafolio", text: $document.person.portfolio)
            }
            Section {
                TextField("Cargos que buscas", text: commaList($document.preferences.roles), prompt: Text("Backend Senior, Tech Lead"))
                TextField("Modalidad", text: $document.preferences.modality, prompt: Text("remoto"))
                TextField("Disponibilidad", text: $document.preferences.availability, prompt: Text("inmediata"))
                TextField("Salario mensual esperado (COP)", value: $document.preferences.copMonthly, format: .number)
                TextField("Salario mínimo (COP)", value: $document.preferences.copMinimum, format: .number)
                TextField("Salario mensual esperado (USD)", value: $document.preferences.usdMonthly, format: .number)
                TextField("Tarifa freelance por hora (USD)", value: $document.preferences.usdHour, format: .number)
            } header: {
                Text("Preferencias")
            } footer: {
                Text("Los agentes usan estos datos al postular y al escribir propuestas. Separa los cargos con comas.")
            }
            ExperienceSection(experience: $document.experience)
            ResumeVariantsSection(variants: $document.cvVariants)
        }
        .formStyle(.grouped)
    }
}

func commaList(_ values: Binding<[String]>) -> Binding<String> {
    Binding(
        get: { values.wrappedValue.joined(separator: ", ") },
        set: { text in values.wrappedValue = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } })
}
