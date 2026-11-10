import Foundation
import HirebarDomain

private let log = Log(.notifications)

public struct Notifier: Sendable {
    public let chat: ChatChannel
    let desktop: DesktopNotifications
    let config: ConfigRepository
    let batches: BatchRepository

    public init(chat: ChatChannel, desktop: DesktopNotifications, config: ConfigRepository, batches: BatchRepository) {
        self.chat = chat
        self.desktop = desktop
        self.config = config
        self.batches = batches
    }

    public var chatId: Int64 { config.load().chatId }

    public var canUseTelegram: Bool {
        chat.isConfigured && !chat.tokenRejected && chatId != 0
    }

    static let messageLimit = 3800

    public func announce(_ batch: Batch, title: String, footer: String) {
        var blocks = [title]
        for (index, item) in batch.items.enumerated() {
            let lines = ["\(index + 1). [\(item.kind)] \(item.title)", item.detail] + (item.url.isEmpty ? [] : [item.url])
            blocks.append(lines.joined(separator: "\n"))
        }
        blocks.append(footer)
        let messages = Self.chunks(blocks, limit: Self.messageLimit)
        guard canUseTelegram else {
            desktop.show(title: title, body: "Configura Telegram en Ajustes → Telegram y avisos para verla y aprobarla.")
            return
        }
        let label = batch.mode == .jobs ? "Sí, postular a todas" : "Sí, enviar todas"
        let chatId = chatId
        sendInOrder(messages, chatId: chatId, buttons: [[(label, "si:\(batch.id)"), ("No", "no:\(batch.id)")]]) { id in
            guard var stored = batches.find(id: batch.id) else { return }
            guard let id else {
                guard stored.status == .pending else { return }
                stored.status = .discarded
                batches.upsert(stored)
                log.write("Telegram: la lista \(batch.id) no llegó completa y se descartó")
                let notice = "No pude mostrarte completa la lista \(batch.id), así que la descarté para que no se apruebe a ciegas."
                tell(notice)
                return
            }
            stored.messageId = id
            batches.upsert(stored)
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

    func sendInOrder(
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
        chat.send(first, chatId: chatId, buttons: rest.isEmpty ? buttons : []) { id in
            if rest.isEmpty || id == nil {
                completion(id)
            } else {
                sendInOrder(rest, chatId: chatId, buttons: buttons, completion: completion)
            }
        }
    }

    static let notificationTitle = "Hirebar"

    public func tell(_ text: String) {
        guard canUseTelegram else {
            desktop.show(title: Self.notificationTitle, body: text)
            return
        }
        chat.send(text, chatId: chatId) { id in
            if id == nil { desktop.show(title: Self.notificationTitle, body: text) }
        }
    }

    public func sendFile(_ file: URL, caption: String) {
        guard canUseTelegram else {
            log.write("Archivo listo sin canal para enviarlo: \(file.path)")
            return
        }
        chat.sendDocument(file, caption: caption, chatId: chatId)
    }

    public func sendPhotos(_ files: [URL], caption: String, completion: @escaping () -> Void) {
        guard canUseTelegram, !files.isEmpty else {
            if let folder = files.first?.deletingLastPathComponent().path {
                log.write("Imágenes listas sin canal para enviarlas: \(folder)")
            }
            completion()
            return
        }
        chat.sendPhotos(files, caption: caption, chatId: chatId, completion: completion)
    }

    public func sendVideo(_ file: URL, caption: String, completion: @escaping () -> Void) {
        guard canUseTelegram else {
            log.write("Video listo sin canal para enviarlo: \(file.path)")
            completion()
            return
        }
        chat.sendVideo(file, caption: caption, chatId: chatId, completion: completion)
    }
}
