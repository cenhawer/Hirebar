import Foundation
import HirebarDomain

public struct TelegramMessage: Sendable {
    public let chatId: Int64
    public let text: String
    public let replyTo: Int?
    public let callbackId: String?
    public var sender: ChannelSender?
    /// Nota de voz o archivo de audio que mandó la persona (identificador de Telegram para descargarlo).
    public var audioFileId: String? = nil
    /// Extensión del audio recibido (oga para notas de voz).
    public var audioExtension: String = "oga"
    public var audioBytes: Int?
    public var audioSeconds: Int?
}

public enum BotCheck: Equatable, Sendable {
    case valid(username: String)
    case rejected
    case unreachable
    case notSaved
}

public final class Telegram: @unchecked Sendable {
    public static let shared = Telegram()
    static let keychainAccount = "telegram-bot"
    static let offsetKey = "telegram.offset"
    static let tokenPattern = "^\\d{5,}:[A-Za-z0-9_-]{30,}$"
    static let unauthorizedCode = 401
    static let notFoundCode = 404

    public var onMessage: ((TelegramMessage) -> Void)?
    private var polling = false
    private let lock = NSLock()
    private var cachedToken: String?
    private var rejected = false
    public var onTokenStateChange: (() -> Void)?

    public var tokenRejected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return rejected
    }

    public static func looksLikeToken(_ token: String) -> Bool {
        token.range(of: tokenPattern, options: .regularExpression) != nil
    }

    public static func check(token: String) async -> BotCheck {
        guard looksLikeToken(token), let url = URL(string: "https://api.telegram.org/bot\(token)/getMe") else { return .rejected }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return .unreachable }
        if let username = (json["result"] as? [String: Any])?["username"] as? String, (json["ok"] as? Bool) == true {
            return .valid(username: username)
        }
        let code = (json["error_code"] as? NSNumber)?.intValue
        return code == unauthorizedCode || code == notFoundCode ? .rejected : .unreachable
    }

    public func botUsername() async -> String? {
        guard let token = currentToken() else { return nil }
        guard case .valid(let username) = await Self.check(token: token) else { return nil }
        return username
    }

    public func chatName(_ chatId: Int64) async -> String? {
        guard let token = currentToken(), let url = URL(string: "https://api.telegram.org/bot\(token)/getChat?chat_id=\(chatId)"),
            let (data, _) = try? await URLSession.shared.data(from: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let chat = json["result"] as? [String: Any]
        else { return nil }
        let name = [chat["first_name"] as? String, chat["last_name"] as? String].compactMap { $0 }.joined(separator: " ")
        return name.isEmpty ? nil : name
    }

    @discardableResult
    public func removeToken() -> Bool {
        guard Keychain.delete(account: Self.keychainAccount) else { return false }
        UserDefaults.standard.set(0, forKey: Self.offsetKey)
        markRejected(false)
        reloadToken()
        return true
    }

    private func markRejected(_ value: Bool) {
        lock.lock()
        let changed = rejected != value
        rejected = value
        lock.unlock()
        guard changed else { return }
        DispatchQueue.main.async { [weak self] in self?.onTokenStateChange?() }
    }

    public var isConfigured: Bool { currentToken() != nil }

    private func currentToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return cachedToken
    }

    public func reloadToken() {
        let value = Keychain.read(account: Self.keychainAccount)
        lock.lock()
        cachedToken = value
        lock.unlock()
    }

    @discardableResult
    public func saveToken(_ token: String) -> Bool {
        guard Keychain.save(token, account: Self.keychainAccount) else { return false }
        UserDefaults.standard.set(0, forKey: Self.offsetKey)
        markRejected(false)
        reloadToken()
        return true
    }

    public func start() {
        reloadToken()
        guard !polling else { return }
        polling = true
        Thread.detachNewThread { [weak self] in self?.pollLoop() }
    }

    private func call(_ method: String, _ params: [String: Any], timeout: TimeInterval = 30) -> [String: Any]? {
        guard let token = currentToken(),
              let url = URL(string: "https://api.telegram.org/bot\(token)/\(method)") else { return nil }
        return Net.postJSON(url, params, timeout: timeout)
    }

    private func pollLoop() {
        var offset = UserDefaults.standard.integer(forKey: Self.offsetKey)
        var lastToken = currentToken()
        while true {
            guard let token = currentToken() else {
                Thread.sleep(forTimeInterval: 15)
                continue
            }
            if token != lastToken {
                lastToken = token
                offset = 0
            }
            let params: [String: Any] = ["offset": offset, "timeout": 50, "allowed_updates": ["message", "callback_query"]]
            let response = call("getUpdates", params, timeout: 70)
            guard currentToken() == token else { continue }
            guard let json = response, (json["ok"] as? Bool) == true, let updates = json["result"] as? [[String: Any]] else {
                if (response?["error_code"] as? NSNumber)?.intValue == Self.unauthorizedCode { markRejected(true) }
                Thread.sleep(forTimeInterval: 15)
                continue
            }
            markRejected(false)
            for update in updates {
                let updateId = (update["update_id"] as? NSNumber)?.intValue ?? 0
                offset = max(offset, updateId + 1)
                UserDefaults.standard.set(offset, forKey: Self.offsetKey)
                if let message = Self.parse(update) {
                    DispatchQueue.main.async { [weak self] in self?.onMessage?(message) }
                }
            }
        }
    }

    public static func parse(_ update: [String: Any]) -> TelegramMessage? {
        if let callback = update["callback_query"] as? [String: Any] {
            let message = callback["message"] as? [String: Any]
            let chat = message?["chat"] as? [String: Any]
            var result = TelegramMessage(
                chatId: (chat?["id"] as? NSNumber)?.int64Value ?? 0,
                text: callback["data"] as? String ?? "",
                replyTo: (message?["message_id"] as? NSNumber)?.intValue,
                callbackId: callback["id"] as? String)
            result.sender = sender(from: callback["from"] as? [String: Any], chat: chat, sentAt: Date(), viaButton: true)
            return result
        }
        guard let message = update["message"] as? [String: Any], let chat = message["chat"] as? [String: Any] else { return nil }
        guard let chatId = (chat["id"] as? NSNumber)?.int64Value else { return nil }
        let reply = (message["reply_to_message"] as? [String: Any])?["message_id"] as? NSNumber
        let sentAt = (message["date"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) } ?? Date()
        let from = sender(from: message["from"] as? [String: Any], chat: chat, sentAt: sentAt)
        if let audio = (message["voice"] ?? message["audio"] ?? message["video_note"]) as? [String: Any],
           let fileId = audio["file_id"] as? String {
            let name = (audio["file_name"] as? String) ?? ""
            let ext = message["voice"] != nil ? "oga" : (message["video_note"] != nil ? "mp4"
                : (name.contains(".") ? String(name.split(separator: ".").last ?? "m4a") : "m4a"))
            var result = TelegramMessage(
                chatId: chatId, text: message["caption"] as? String ?? "", replyTo: reply?.intValue, callbackId: nil)
            result.audioFileId = fileId
            result.audioExtension = ext
            result.audioBytes = (audio["file_size"] as? NSNumber)?.intValue
            result.audioSeconds = (audio["duration"] as? NSNumber)?.intValue
            result.sender = from
            return result
        }
        guard let text = message["text"] as? String else { return nil }
        var result = TelegramMessage(chatId: chatId, text: text, replyTo: reply?.intValue, callbackId: nil)
        result.sender = from
        return result
    }

    static let privateChatType = "private"

    static func sender(from user: [String: Any]?, chat: [String: Any]?, sentAt: Date, viaButton: Bool = false) -> ChannelSender? {
        guard let user, let userId = (user["id"] as? NSNumber)?.int64Value,
            let chatId = (chat?["id"] as? NSNumber)?.int64Value
        else { return nil }
        let name = [user["first_name"] as? String, user["last_name"] as? String].compactMap { $0 }.joined(separator: " ")
        return ChannelSender(
            userId: userId, chatId: chatId, name: name, username: user["username"] as? String,
            isPrivateChat: (chat?["type"] as? String) == privateChatType, sentAt: sentAt, viaButton: viaButton)
    }

    public func send(_ text: String, chatId: Int64, buttons: [[(String, String)]] = [], completion: ((Int?) -> Void)? = nil) {
        var params: [String: Any] = ["chat_id": chatId, "text": String(text.prefix(4000)),
                                     "disable_web_page_preview": true]
        if !buttons.isEmpty {
            params["reply_markup"] = ["inline_keyboard": buttons.map { row in
                row.map { ["text": $0.0, "callback_data": $0.1] }
            }]
        }
        let payload = params
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = self?.call("sendMessage", payload)
            let id = ((result?["result"] as? [String: Any])?["message_id"] as? NSNumber)?.intValue
            if id == nil { Log.write("Telegram: no se pudo enviar (\(result?["description"] ?? "sin respuesta"))") }
            DispatchQueue.main.async { completion?(id) }
        }
    }

    public func sendDocument(_ file: URL, caption: String, chatId: Int64) {
        guard let token = currentToken(),
              let url = URL(string: "https://api.telegram.org/bot\(token)/sendDocument") else { return }
        let fields = ["chat_id": String(chatId), "caption": String(caption.prefix(1000))]
        DispatchQueue.global(qos: .utility).async {
            let result = Net.postMultipart(url, fields: fields, fileField: "document", file: file)
            if (result?["ok"] as? Bool) != true {
                Log.write("Telegram: no se pudo enviar \(file.lastPathComponent) (\(result?["description"] ?? "sin respuesta"))")
            }
        }
    }

    /// Manda las imágenes una por una, en orden, y avisa al terminar.
    public func sendPhotos(_ files: [URL], caption: String, chatId: Int64, completion: (() -> Void)? = nil) {
        guard let token = currentToken(),
              let url = URL(string: "https://api.telegram.org/bot\(token)/sendPhoto") else {
            completion?()
            return
        }
        DispatchQueue.global(qos: .utility).async {
            for (index, file) in files.enumerated() {
                var fields = ["chat_id": String(chatId)]
                if index == 0 && !caption.isEmpty { fields["caption"] = String(caption.prefix(1000)) }
                var result = Net.postMultipart(url, fields: fields, fileField: "photo", file: file)
                for _ in 0..<2 where (result?["ok"] as? Bool) != true {
                    Thread.sleep(forTimeInterval: 3)
                    result = Net.postMultipart(url, fields: fields, fileField: "photo", file: file)
                }
                if (result?["ok"] as? Bool) != true {
                    Log.write("Telegram: no se pudo enviar la imagen \(file.lastPathComponent) (\(result?["description"] ?? "sin respuesta"))")
                }
            }
            DispatchQueue.main.async { completion?() }
        }
    }

    public func sendVideo(_ file: URL, caption: String, chatId: Int64, completion: (() -> Void)? = nil) {
        guard let token = currentToken(),
              let url = URL(string: "https://api.telegram.org/bot\(token)/sendVideo") else {
            completion?()
            return
        }
        let fields = ["chat_id": String(chatId), "caption": String(caption.prefix(1000)), "supports_streaming": "true"]
        DispatchQueue.global(qos: .utility).async {
            var result = Net.postMultipart(url, fields: fields, fileField: "video", file: file, timeout: 300)
            if (result?["ok"] as? Bool) != true {
                Thread.sleep(forTimeInterval: 5)
                result = Net.postMultipart(url, fields: fields, fileField: "video", file: file, timeout: 300)
            }
            if (result?["ok"] as? Bool) != true {
                Log.write("Telegram: no se pudo enviar el video \(file.lastPathComponent) (\(result?["description"] ?? "sin respuesta"))")
            }
            DispatchQueue.main.async { completion?() }
        }
    }

    /// Descarga un archivo que mandó la persona (por ejemplo, una nota de voz). Llamar desde un hilo de fondo.
    public func download(fileId: String, to target: URL, maxBytes: Int? = nil) -> Bool {
        guard let token = currentToken(),
              let info = call("getFile", ["file_id": fileId]),
              let path = (info["result"] as? [String: Any])?["file_path"] as? String,
              let url = URL(string: "https://api.telegram.org/file/bot\(token)/\(path)") else { return false }
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
        let payload = params
        DispatchQueue.global(qos: .utility).async { [weak self] in _ = self?.call("answerCallbackQuery", payload) }
    }

    public func removeButtons(chatId: Int64, messageId: Int) {
        let params: [String: Any] = ["chat_id": chatId, "message_id": messageId,
                                     "reply_markup": ["inline_keyboard": [[String: String]]()]]
        DispatchQueue.global(qos: .utility).async { [weak self] in _ = self?.call("editMessageReplyMarkup", params) }
    }
}
