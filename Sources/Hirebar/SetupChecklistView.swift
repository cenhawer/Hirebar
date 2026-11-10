import HirebarApplication
import SwiftUI

struct SetupChecklistList: View {
    let pending: [SetupStep]
    let emptyText: LocalizedStringKey

    var body: some View {
        if pending.isEmpty {
            Label(emptyText, systemImage: "checkmark.seal.fill").foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(pending, id: \.self) { step in
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(step.title)
                            Text(step.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "circle").foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}

struct SetupChecklistSection: View {
    let pending: [SetupStep]
    let open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Falta configurar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Abrir asistente", action: open)
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
            }
            ForEach(pending, id: \.self) { step in
                Button(action: open) {
                    Label(step.title, systemImage: "circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help(step.detail)
            }
        }
    }
}
