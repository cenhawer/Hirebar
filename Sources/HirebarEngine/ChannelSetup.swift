import Foundation
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram

private let log = Log(.telegram)

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

public final class ChannelSetup {
    let settings: ChannelSettings?
    let clock: Clock
    let chat: ChatChannel
    private var pairing: ChannelPairing?
    private var guardian: ChannelGuard
    public var onChange: ((ChannelState) -> Void)?

    let configs: ConfigRepository

    init(settings: ChannelSettings?, chat: ChatChannel, configs: ConfigRepository, clock: Clock) {
        self.configs = configs
        self.settings = settings
        self.chat = chat
        self.clock = clock
        guardian = ChannelGuard(messagesPerMinute: settings?.messagesPerMinute ?? 0)
    }

    public var state: ChannelState {
        guard settings != nil else { return .misconfigured }
        guard chat.isConfigured else { return .notConfigured }
        if chat.tokenRejected { return .tokenRejected }
        let config = configs.load()
        let bot = config.botUsername
        if let owner = config.channelOwner { return .connected(owner, bot: bot) }
        guard let pairing else { return .unlinked(bot: bot) }
        if pairing.isExpired(at: clock.now()) { return .expired(bot: bot) }
        if let candidate = pairing.current { return .confirming(candidate, bot: bot) }
        return .waitingForHello(bot: bot)
    }

    @MainActor
    public func useToken(_ token: String) async -> BotCheck {
        let check = await chat.checkToken(token)
        guard case .valid(let username) = check else { return check }
        guard chat.saveToken(token) else { return .notSaved }
        var config = configs.load()
        config.channelOwner = nil
        config.botUsername = username
        configs.save(config)
        chat.start()
        startPairing()
        return check
    }

    public func startPairing() {
        guard let settings else { return }
        let started = clock.now()
        pairing = ChannelPairing(startedAt: started, window: settings.pairingWindow)
        notify()
        clock.after(settings.pairingWindow) { [weak self] in
            guard let self, self.pairing?.startedAt == started else { return }
            self.notify()
        }
    }

    public func cancelPairing() {
        pairing = nil
        notify()
    }

    func offer(_ sender: ChannelSender, text: String) -> Bool {
        guard configs.load().channelOwner == nil, pairing != nil, pairing?.receive(sender, text: text, at: clock.now()) == true else {
            return false
        }
        notify()
        return true
    }

    public func confirm(welcome: String) {
        guard let candidate = pairing?.current else { return }
        var config = configs.load()
        config.channelOwner = candidate.owner
        configs.save(config)
        pairing = nil
        log.write("Telegram: bot anclado a la cuenta confirmada")
        chat.send(welcome, chatId: candidate.owner.chatId)
        notify()
    }

    public func decline() {
        pairing?.declineCurrent()
        notify()
    }

    public func changeAccount() {
        var config = configs.load()
        config.channelOwner = nil
        configs.save(config)
        startPairing()
    }

    public func removeBot() -> ChannelChange {
        guard chat.removeToken() else { return .keychainFailed }
        var config = configs.load()
        config.channelOwner = nil
        config.botUsername = ""
        configs.save(config)
        pairing = nil
        notify()
        return .done
    }

    func admit(_ sender: ChannelSender) -> ChannelDecision {
        guardian.check(sender, owner: configs.load().channelOwner, now: clock.now())
    }

    @MainActor
    public func completeMissingDetails() async {
        var config = configs.load()
        guard chat.isConfigured else { return }
        if config.botUsername.isEmpty, let username = await chat.botUsername() {
            config.botUsername = username
        }
        if let owner = config.channelOwner, owner.name.isEmpty, let name = await chat.chatName(owner.chatId) {
            config.channelOwner = ChannelOwner(userId: owner.userId, chatId: owner.chatId, name: name, username: owner.username)
        }
        configs.save(config)
        notify()
    }

    func tokenStateChanged() {
        notify()
    }

    private func notify() {
        onChange?(state)
    }
}
