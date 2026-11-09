import Foundation
import HirebarApplication
import HirebarCore
import HirebarDomain

public enum ChannelState: Equatable, Sendable {
    case misconfigured
    case notConfigured
    case tokenRejected
    case unlinked(bot: String)
    case waitingForHello(bot: String)
    case confirming(PairingCandidate, bot: String)
    case expired(bot: String)
    case connected(ChannelOwner, bot: String)
}

public enum ChannelChange: Equatable, Sendable {
    case done
    case keychainFailed
}

struct ChannelTelegram {
    var isConfigured: () -> Bool
    var tokenRejected: () -> Bool
    var send: (String, Int64) -> Void
    var saveToken: (String) -> Bool
    var removeToken: () -> Bool
    var start: () -> Void

    static let live = ChannelTelegram(
        isConfigured: { Telegram.shared.isConfigured },
        tokenRejected: { Telegram.shared.tokenRejected },
        send: { text, chatId in Telegram.shared.send(text, chatId: chatId) },
        saveToken: { Telegram.shared.saveToken($0) },
        removeToken: { Telegram.shared.removeToken() },
        start: { Telegram.shared.start() }
    )
}

public final class ChannelSetup {
    let settings: ChannelSettings?
    let now: () -> Date
    let telegram: ChannelTelegram
    private var pairing: ChannelPairing?
    private var guardian: ChannelGuard
    public var onChange: ((ChannelState) -> Void)?

    init(settings: ChannelSettings?, telegram: ChannelTelegram = .live, now: @escaping () -> Date = Date.init) {
        self.settings = settings
        self.telegram = telegram
        self.now = now
        guardian = ChannelGuard(messagesPerMinute: settings?.messagesPerMinute ?? 0)
    }

    public var state: ChannelState {
        guard settings != nil else { return .misconfigured }
        guard telegram.isConfigured() else { return .notConfigured }
        if telegram.tokenRejected() { return .tokenRejected }
        let config = Config.load()
        let bot = config.botUsername
        if let owner = config.channelOwner { return .connected(owner, bot: bot) }
        guard let pairing else { return .unlinked(bot: bot) }
        if pairing.isExpired(at: now()) { return .expired(bot: bot) }
        if let candidate = pairing.current { return .confirming(candidate, bot: bot) }
        return .waitingForHello(bot: bot)
    }

    @MainActor
    public func useToken(_ token: String) async -> BotCheck {
        let check = await Telegram.check(token: token)
        guard case .valid(let username) = check else { return check }
        guard telegram.saveToken(token) else { return .notSaved }
        var config = Config.load()
        config.channelOwner = nil
        config.botUsername = username
        config.save()
        telegram.start()
        startPairing()
        return check
    }

    public func startPairing() {
        guard let settings else { return }
        let started = now()
        pairing = ChannelPairing(startedAt: started, window: settings.pairingWindow)
        notify()
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.pairingWindow) { [weak self] in
            guard let self, self.pairing?.startedAt == started else { return }
            self.notify()
        }
    }

    public func cancelPairing() {
        pairing = nil
        notify()
    }

    func offer(_ sender: ChannelSender, text: String) -> Bool {
        guard Config.load().channelOwner == nil, pairing != nil, pairing?.receive(sender, text: text, at: now()) == true else {
            return false
        }
        notify()
        return true
    }

    public func confirm(welcome: String) {
        guard let candidate = pairing?.current else { return }
        var config = Config.load()
        config.channelOwner = candidate.owner
        config.save()
        pairing = nil
        Log.write("Telegram: bot anclado a la cuenta confirmada")
        telegram.send(welcome, candidate.owner.chatId)
        notify()
    }

    public func decline() {
        pairing?.declineCurrent()
        notify()
    }

    public func changeAccount() {
        var config = Config.load()
        config.channelOwner = nil
        config.save()
        startPairing()
    }

    public func removeBot() -> ChannelChange {
        guard telegram.removeToken() else { return .keychainFailed }
        var config = Config.load()
        config.channelOwner = nil
        config.botUsername = ""
        config.save()
        pairing = nil
        notify()
        return .done
    }

    func admit(_ sender: ChannelSender) -> ChannelDecision {
        guardian.check(sender, owner: Config.load().channelOwner, now: now())
    }

    @MainActor
    public func completeMissingDetails() async {
        var config = Config.load()
        guard telegram.isConfigured() else { return }
        if config.botUsername.isEmpty, let username = await Telegram.shared.botUsername() {
            config.botUsername = username
        }
        if let owner = config.channelOwner, owner.name.isEmpty, let name = await Telegram.shared.chatName(owner.chatId) {
            config.channelOwner = ChannelOwner(userId: owner.userId, chatId: owner.chatId, name: name, username: owner.username)
        }
        config.save()
        notify()
    }

    func tokenStateChanged() {
        notify()
    }

    private func notify() {
        onChange?(state)
    }
}
