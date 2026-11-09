import Foundation

public enum Notifier {
    public static var canUseTelegram: Bool { Telegram.shared.isConfigured && Config.load().chatId != 0 }

    static let messageLimit = 3800

    public static func announce(_ batch: Batch, title: String, footer: String) {
        var blocks = [title]
        for (index, item) in batch.items.enumerated() {
            let lines = ["\(index + 1). [\(item.kind)] \(item.title)", item.detail] + (item.url.isEmpty ? [] : [item.url])
            blocks.append(lines.joined(separator: "\n"))
        }
        blocks.append(footer)
        let messages = chunks(blocks, limit: messageLimit)
        guard canUseTelegram else {
            let hint = "(Configura Telegram en el menú de Hirebar para responder \"si\" desde el celular.)"
            ntfy(title: title, message: messages.joined(separator: "\n\n") + "\n\n" + hint)
            return
        }
        let label = batch.mode == .jobs ? "Sí, postular a todas" : "Sí, enviar todas"
        let chatId = Config.load().chatId
        sendInOrder(messages, chatId: chatId, buttons: [[(label, "si:\(batch.id)"), ("No", "no:\(batch.id)")]]) { id in
            guard var stored = BatchStore.find(id: batch.id) else { return }
            guard let id else {
                guard stored.status == .pending else { return }
                stored.status = .discarded
                BatchStore.upsert(stored)
                Log.write("Telegram: la lista \(batch.id) no llegó completa y se descartó")
                let notice = "No pude mostrarte completa la lista \(batch.id), así que la descarté para que no se apruebe a ciegas."
                Telegram.shared.send(notice, chatId: chatId)
                return
            }
            stored.messageId = id
            BatchStore.upsert(stored)
        }
    }

    static func chunks(_ blocks: [String], limit: Int) -> [String] {
        var messages: [String] = []
        var current = ""
        for block in blocks.flatMap({ pieces(of: $0, limit: limit) }) {
            if !current.isEmpty && current.count + 2 + block.count > limit {
                messages.append(current)
                current = ""
            }
            current += (current.isEmpty ? "" : "\n\n") + block
        }
        if !current.isEmpty { messages.append(current) }
        return messages
    }

    static func pieces(of block: String, limit: Int) -> [String] {
        guard block.count > limit else { return [block] }
        var pieces: [String] = []
        var rest = Substring(block)
        while !rest.isEmpty {
            pieces.append(String(rest.prefix(limit)))
            rest = rest.dropFirst(limit)
        }
        return pieces
    }

    static func sendInOrder(
        _ messages: [String],
        chatId: Int64,
        buttons: [[(String, String)]],
        completion: @escaping (Int?) -> Void
    ) {
        guard let first = messages.first else {
            completion(nil)
            return
        }
        let rest = Array(messages.dropFirst())
        Telegram.shared.send(first, chatId: chatId, buttons: rest.isEmpty ? buttons : []) { id in
            if rest.isEmpty || id == nil {
                completion(id)
            } else {
                sendInOrder(rest, chatId: chatId, buttons: buttons, completion: completion)
            }
        }
    }

    public static func tell(_ text: String) {
        if canUseTelegram {
            Telegram.shared.send(text, chatId: Config.load().chatId)
        } else {
            ntfy(title: "Hirebar", message: text)
        }
    }

    public static func sendFile(_ file: URL, caption: String) {
        guard canUseTelegram else {
            Log.write("Archivo listo sin canal para enviarlo: \(file.path)")
            return
        }
        Telegram.shared.sendDocument(file, caption: caption, chatId: Config.load().chatId)
    }

    public static func sendPhotos(_ files: [URL], caption: String, completion: @escaping () -> Void) {
        guard canUseTelegram, !files.isEmpty else {
            if !files.isEmpty { Log.write("Imágenes listas sin canal para enviarlas: \(files.first?.deletingLastPathComponent().path ?? "")") }
            completion()
            return
        }
        Telegram.shared.sendPhotos(files, caption: caption, chatId: Config.load().chatId, completion: completion)
    }

    public static func sendVideo(_ file: URL, caption: String, completion: @escaping () -> Void) {
        guard canUseTelegram else {
            Log.write("Video listo sin canal para enviarlo: \(file.path)")
            completion()
            return
        }
        Telegram.shared.sendVideo(file, caption: caption, chatId: Config.load().chatId, completion: completion)
    }

    public static func ntfy(title: String, message: String) {
        let topic = Config.load().ntfyTopic
        guard !topic.isEmpty, let url = URL(string: "https://ntfy.sh/") else {
            Log.write("Aviso sin canal (configura Telegram o ntfy): \(title)")
            return
        }
        let body: [String: Any] = ["topic": topic, "title": title,
                                   "message": String(message.prefix(3800)), "priority": 4, "tags": ["briefcase"]]
        DispatchQueue.global(qos: .utility).async { _ = Net.postJSON(url, body, timeout: 20) }
    }
}
