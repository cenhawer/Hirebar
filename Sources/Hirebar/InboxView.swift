import AVKit
import HirebarApplication
import HirebarDomain
import SwiftUI

struct InboxView: View {
    @Bindable var model: InboxModel

    var body: some View {
        Group {
            if model.isEmpty {
                ContentUnavailableView(
                    "Nada pendiente", systemImage: "tray",
                    description: Text("Cuando un agente arme una lista o una publicación, aparece aquí para aprobarla."))
            } else {
                List {
                    ForEach(model.drafts) { draft in
                        Section(draft.title) { DraftCard(draft: draft, model: model) }
                    }
                    ForEach(model.lists) { list in
                        Section {
                            ListCard(list: list, model: model)
                        } header: {
                            Text("\(list.title) · \(list.created.formatted(date: .abbreviated, time: .shortened))")
                        }
                    }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}

struct ListCard: View {
    let list: InboxList
    @Bindable var model: InboxModel
    @State private var confirmingDiscard = false

    var body: some View {
        ForEach(list.items) { item in
            HStack(alignment: .top, spacing: 10) {
                Toggle(
                    isOn: Binding(
                        get: { model.selection.isSelected(item.number, in: list.id) },
                        set: { _ in model.selection.toggle(item.number, in: list.id) })
                ) {
                    EmptyView()
                }
                .toggleStyle(.checkbox)
                .accessibilityLabel(Text("Elegir \(item.title)"))
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(item.number). \(item.title)").font(.headline)
                    Text("\(item.platform) · \(item.kind)").font(.caption).foregroundStyle(.secondary)
                    if !item.target.isEmpty {
                        Button(item.target) { model.open(item.target) }
                            .buttonStyle(.link)
                            .font(.caption)
                    }
                    Text(item.detail).font(.callout).textSelection(.enabled)
                }
            }
            .padding(.vertical, 4)
        }
        HStack {
            Button("Descartar", role: .destructive) { confirmingDiscard = true }
            Spacer()
            Button("Aprobar elegidos (\(model.selection.count(in: list.id)))") { model.approveSelected(list) }
                .disabled(model.selection.picks(for: list) == nil)
            Button("Aprobar todos") { model.approveAll(list) }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            "¿Descartar esta lista?", isPresented: $confirmingDiscard, titleVisibility: .visible
        ) {
            Button("Descartar", role: .destructive) { model.discard(list) }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se pierden los \(list.items.count) elementos revisados de esta lista.")
        }
    }
}

struct DraftCard: View {
    let draft: InboxDraft
    let model: InboxModel
    @State private var confirmingSkip = false
    @State private var confirmingPublish = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(draft.text).font(.callout).textSelection(.enabled)
            if !draft.slides.isEmpty {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 8) {
                        ForEach(draft.slides, id: \.self) { slide in
                            if let image = NSImage(contentsOf: slide) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 220)
                                    .accessibilityLabel(Text("Lámina \(slide.deletingPathExtension().lastPathComponent)"))
                            }
                        }
                    }
                }
            }
            if let video = draft.video {
                VideoPlayer(player: AVPlayer(url: video))
                    .frame(height: 320)
                    .accessibilityLabel(Text("Video de la publicación"))
            }
            HStack {
                Button("No publicar", role: .destructive) { confirmingSkip = true }
                Spacer()
                Button("Publicar") { confirmingPublish = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            "¿Descartar esta publicación?", isPresented: $confirmingSkip, titleVisibility: .visible
        ) {
            Button("No publicar", role: .destructive) { model.skip(draft) }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("No se publica y se pierde el borrador de \(draft.title).")
        }
        .confirmationDialog(
            "¿Publicar ahora?", isPresented: $confirmingPublish, titleVisibility: .visible
        ) {
            Button("Publicar") { model.publish(draft) }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se publica de inmediato en \(draft.title) y no se puede deshacer.")
        }
    }
}
