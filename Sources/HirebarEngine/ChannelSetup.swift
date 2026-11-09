import Foundation
import HirebarApplication
import HirebarCore
import HirebarDomain

public enum ChannelState: Equatable, Sendable {
    case notConfigured
    case tokenRejected
    case unlinked(bot: String)
    case waitingForHello(bot: String)
    case confirming(ChannelOwner, bot: String)
    case expired(bot: String)
    case connected(ChannelOwner, bot: String)
}

public final class ChannelSetup {
    let settings: ChannelSettings?
    let now: () -> Date
    private var pairing: ChannelPairing?
    private var candidate: ChannelOwner?
    private var guardian: ChannelGuard
    public var onChange: ((ChannelState) -> Void)?

    init(settings: ChannelSettings?, now: @escaping () -> Date = Date.init) {
        self.settings = settings
        self.now = now
        guardian = ChannelGuard(messagesPerMinute: settings?.messagesPerMinute ?? Int.max)
    }

    public var state: ChannelState {
        let config = Config.load()
        guard Telegram.shared.isConfigured else { return .notConfigured }
        if Telegram.shared.tokenRejected { return .tokenRejected }
        let bot = config.botUsername
        if let owner = config.channelOwner { return .connected(owner, bot: bot) }
        if let candidate { return .confirming(candidate, bot: bot) }
        if let pairing { return pairing.isExpired(at: now()) ? .expired(bot: bot) : .waitingForHello(bot: bot) }
        return .unlinked(bot: bot)
    }

    public var pairingMinutes: Int? { settings?.pairingMinutes }

    @MainActor
    public func useToken(_ token: String) async -> BotCheck {
        let check = await Telegram.check(token: token)
        guard case .valid(let username) = check else { return check }
        guard Telegram.shared.saveToken(token) else { return .unreachable }
        var config = Config.load()
        config.channelOwner = nil
        config.botUsername = username
        config.save()
        Telegram.shared.start()
        startPairing()
        return check
    }

    public func startPairing() {
        guard let settings else {
            Log.write("Telegram: falta canal.json en la app; no se puede vincular")
            return
        }
        let started = now()
        pairing = ChannelPairing(startedAt: started, window: settings.pairingWindow)
        candidate = nil
        notify()
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.pairingWindow) { [weak self] in
            guard let self, self.pairing?.startedAt == started, self.candidate == nil else { return }
            self.notify()
        }
    }

    func offer(_ sender: ChannelSender) -> Bool {
        guard Config.load().channelOwner == nil, candidate == nil, let pairing,
            let proposed = pairing.candidate(from: sender, at: now())
        else { return false }
        candidate = proposed
        notify()
        return true
    }

    public func confirm(welcome: String) {
        guard let candidate else { return }
        var config = Config.load()
        config.channelOwner = candidate
        config.save()
        pairing = nil
        self.candidate = nil
        Log.write("Telegram: bot anclado a la cuenta de \(candidate.name)")
        Telegram.shared.send(welcome, chatId: candidate.chatId)
        notify()
    }

    public func decline() {
        guard let rejected = candidate else { return }
        pairing?.decline(rejected)
        candidate = nil
        notify()
    }

    public func changeAccount() {
        var config = Config.load()
        config.channelOwner = nil
        config.save()
        startPairing()
    }

    public func removeBot() {
        var config = Config.load()
        config.channelOwner = nil
        config.botUsername = ""
        config.save()
        Telegram.shared.removeToken()
        pairing = nil
        candidate = nil
        notify()
    }

    func admit(_ sender: ChannelSender) -> ChannelDecision {
        guardian.check(sender, owner: Config.load().channelOwner, now: now())
    }

    private func notify() {
        onChange?(state)
    }
}
