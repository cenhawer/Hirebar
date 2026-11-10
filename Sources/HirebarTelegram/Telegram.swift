import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.telegram)

public final class Telegram: @unchecked Sendable {
    let secrets: SecretStore
    let offsets: ChatOffsetStore

    public init(secrets: SecretStore, offsets: ChatOffsetStore) {
        self.secrets = secrets
        self.offsets = offsets
    }

    static let keychainAccount = "telegram-bot"
    static let tokenPattern = "^\\d{5,}:[A-Za-z0-9_-]{30,}$"
    static let unauthorizedCode = 401
    static let notFoundCode = 404

    public var onMessage: (@MainActor (ChatMessage) -> Void)?
    private var polling = false
    private let lock = NSLock()
    private var cachedToken: String?
    private var rejected = false
    public var onTokenStateChange: (@MainActor () -> Void)?

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
        guard secrets.delete(Self.keychainAccount) else { return false }
        offsets.saveChatOffset(0)
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

    func currentToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return cachedToken
    }

    public func reloadToken() {
        let value = secrets.secret(for: Self.keychainAccount)
        lock.lock()
        cachedToken = value
        lock.unlock()
    }

    @discardableResult
    public func saveToken(_ token: String) -> Bool {
        guard secrets.save(token, for: Self.keychainAccount) else { return false }
        offsets.saveChatOffset(0)
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

    func call(_ method: String, _ params: [String: Any], timeout: TimeInterval = 30) -> [String: Any]? {
        guard let token = currentToken(),
            let url = URL(string: "https://api.telegram.org/bot\(token)/\(method)")
        else { return nil }
        return TelegramHTTP.postJSON(url, params, timeout: timeout)
    }

    func call(_ method: String, body: Data?, timeout: TimeInterval = 30) -> [String: Any]? {
        guard let token = currentToken(),
            let url = URL(string: "https://api.telegram.org/bot\(token)/\(method)")
        else { return nil }
        return TelegramHTTP.postJSON(url, data: body, timeout: timeout)
    }

    private func pollLoop() {
        var offset = offsets.chatOffset()
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
                offsets.saveChatOffset(offset)
                if let message = Self.parse(update) {
                    DispatchQueue.main.async { [weak self] in self?.onMessage?(message) }
                }
            }
        }
    }
}

extension Telegram: ChatChannel {
    public func checkToken(_ token: String) async -> BotCheck {
        await Self.check(token: token)
    }
}
