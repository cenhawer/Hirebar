import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.telegram)

extension Telegram {
    public func send(_ text: String, chatId: Int64, buttons: ChatButtons = [], completion: (@MainActor @Sendable (Int?) -> Void)? = nil) {
        var params: [String: Any] = [
            "chat_id": chatId, "text": String(text.prefix(4000)),
            "disable_web_page_preview": true,
        ]
        if !buttons.isEmpty {
            let keyboard = buttons.map { row in row.map { ["text": $0.0, "callback_data": $0.1] } }
            params["reply_markup"] = ["inline_keyboard": keyboard]
        }
        let payload = TelegramHTTP.encode(params)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = self?.call("sendMessage", body: payload)
            let id = ((result?["result"] as? [String: Any])?["message_id"] as? NSNumber)?.intValue
            if id == nil { log.write("Telegram: no se pudo enviar (\(result?["description"] ?? "sin respuesta"))") }
            Task { @MainActor in completion?(id) }
        }
    }

    public func sendDocument(_ file: URL, caption: String, chatId: Int64) {
        guard let token = currentToken(),
            let url = URL(string: "https://api.telegram.org/bot\(token)/sendDocument")
        else { return }
        let fields = ["chat_id": String(chatId), "caption": String(caption.prefix(1000))]
        DispatchQueue.global(qos: .utility).async {
            let result = TelegramHTTP.postMultipart(url, fields: fields, fileField: "document", file: file)
            if (result?["ok"] as? Bool) != true {
                log.write("Telegram: no se pudo enviar \(file.lastPathComponent) (\(result?["description"] ?? "sin respuesta"))")
            }
        }
    }

    public func sendPhotos(_ files: [URL], caption: String, chatId: Int64, completion: (@MainActor @Sendable () -> Void)? = nil) {
        guard let token = currentToken(),
            let url = URL(string: "https://api.telegram.org/bot\(token)/sendPhoto")
        else {
            Task { @MainActor in completion?() }
            return
        }
        DispatchQueue.global(qos: .utility).async {
            for (index, file) in files.enumerated() {
                var fields = ["chat_id": String(chatId)]
                if index == 0 && !caption.isEmpty { fields["caption"] = String(caption.prefix(1000)) }
                var result = TelegramHTTP.postMultipart(url, fields: fields, fileField: "photo", file: file)
                for _ in 0..<2 where (result?["ok"] as? Bool) != true {
                    Thread.sleep(forTimeInterval: 3)
                    result = TelegramHTTP.postMultipart(url, fields: fields, fileField: "photo", file: file)
                }
                if (result?["ok"] as? Bool) != true {
                    let reason = result?["description"] ?? "sin respuesta"
                    log.write("Telegram: no se pudo enviar la imagen \(file.lastPathComponent) (\(reason))")
                }
            }
            Task { @MainActor in completion?() }
        }
    }

    public func sendVideo(_ file: URL, caption: String, chatId: Int64, completion: (@MainActor @Sendable () -> Void)? = nil) {
        guard let token = currentToken(),
            let url = URL(string: "https://api.telegram.org/bot\(token)/sendVideo")
        else {
            Task { @MainActor in completion?() }
            return
        }
        let fields = ["chat_id": String(chatId), "caption": String(caption.prefix(1000)), "supports_streaming": "true"]
        DispatchQueue.global(qos: .utility).async {
            var result = TelegramHTTP.postMultipart(url, fields: fields, fileField: "video", file: file, timeout: 300)
            if (result?["ok"] as? Bool) != true {
                Thread.sleep(forTimeInterval: 5)
                result = TelegramHTTP.postMultipart(url, fields: fields, fileField: "video", file: file, timeout: 300)
            }
            if (result?["ok"] as? Bool) != true {
                log.write("Telegram: no se pudo enviar el video \(file.lastPathComponent) (\(result?["description"] ?? "sin respuesta"))")
            }
            Task { @MainActor in completion?() }
        }
    }

    public func download(fileId: String, to target: URL, maxBytes: Int? = nil) -> Bool {
        guard let token = currentToken(),
            let info = call("getFile", ["file_id": fileId]),
            let path = (info["result"] as? [String: Any])?["file_path"] as? String,
            let url = URL(string: "https://api.telegram.org/file/bot\(token)/\(path)")
        else { return false }
        final class Box: @unchecked Sendable { var data: Data? }
        let box = Box()
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: URLRequest(url: url, timeoutInterval: 120)) { data, response, _ in
            if (response as? HTTPURLResponse)?.statusCode == 200 { box.data = data }
            done.signal()
        }.resume()
        done.wait()
        guard let data = box.data, data.count > 500, data.count <= (maxBytes ?? Int.max) else { return false }
        return (try? data.write(to: target, options: .atomic)) != nil
    }

    public func answerCallback(_ id: String, text: String? = nil) {
        var params: [String: Any] = ["callback_query_id": id]
        if let text { params["text"] = text }
        let payload = TelegramHTTP.encode(params)
        DispatchQueue.global(qos: .utility).async { [weak self] in _ = self?.call("answerCallbackQuery", body: payload) }
    }

    public func removeButtons(chatId: Int64, messageId: Int) {
        let params: [String: Any] = [
            "chat_id": chatId, "message_id": messageId,
            "reply_markup": ["inline_keyboard": [[String: String]]()],
        ]
        let payload = TelegramHTTP.encode(params)
        DispatchQueue.global(qos: .utility).async { [weak self] in _ = self?.call("editMessageReplyMarkup", body: payload) }
    }
}
