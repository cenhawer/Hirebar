import Foundation
import HirebarDomain

public enum PermissionState: Equatable, Sendable {
    case allowed
    case denied
    case undecided
}

public enum SystemPermission: Sendable {
    case voiceRecognition
    case notifications
}

@MainActor
public protocol SystemPermissions {
    func state(of permission: SystemPermission) async -> PermissionState
    func request(_ permission: SystemPermission) async -> PermissionState
}

public enum SetupStep: String, CaseIterable, Sendable {
    case owner
    case aiEngine
    case channel
    case agents
    case voice
    case notifications

    public static let essential: [SetupStep] = [.owner, .aiEngine, .channel]

    public var title: String {
        switch self {
        case .owner: return String(localized: "Tu nombre")
        case .aiEngine: return String(localized: "Motor de IA probado")
        case .channel: return String(localized: "Telegram conectado")
        case .agents: return String(localized: "Al menos un agente prendido")
        case .voice: return String(localized: "Permiso de reconocimiento de voz")
        case .notifications: return String(localized: "Permiso de notificaciones")
        }
    }

    public var detail: String {
        switch self {
        case .owner: return String(localized: "Firma los correos, las propuestas y las publicaciones.")
        case .aiEngine: return String(localized: "Hirebar prueba que la IA responde antes de mandarle trabajo.")
        case .channel: return String(localized: "Por ahí llegan las listas para aprobar y las respuestas.")
        case .agents: return String(localized: "Prende los agentes que quieres que trabajen.")
        case .voice: return String(localized: "Hace falta para armar el video con tu nota de voz.")
        case .notifications: return String(localized: "Avisan en la Mac cuando Telegram no está disponible.")
        }
    }
}

public struct SetupFacts: Equatable, Sendable {
    public var ownerName: String
    public var engineVerified: Bool
    public var channelConnected: Bool
    public var enabledAgents: Int
    public var usesVoice: Bool
    public var voiceRecognition: PermissionState
    public var notifications: PermissionState

    public init(
        ownerName: String, engineVerified: Bool, channelConnected: Bool, enabledAgents: Int, usesVoice: Bool,
        voiceRecognition: PermissionState, notifications: PermissionState
    ) {
        self.ownerName = ownerName
        self.engineVerified = engineVerified
        self.channelConnected = channelConnected
        self.enabledAgents = enabledAgents
        self.usesVoice = usesVoice
        self.voiceRecognition = voiceRecognition
        self.notifications = notifications
    }

    public init(
        config: Config, agents: [AgentSettings], accounts: [ContentAccount], channel: ChannelState,
        voiceRecognition: PermissionState, notifications: PermissionState
    ) {
        var connected = false
        if case .connected = channel { connected = true }
        self.init(
            ownerName: config.ownerName, engineVerified: config.verifiedEngine == config.aiEngine.kind, channelConnected: connected,
            enabledAgents: agents.filter(\.enabled).count, usesVoice: accounts.contains { $0.enabled && $0.video },
            voiceRecognition: voiceRecognition, notifications: notifications)
    }
}

public enum SetupChecklist {
    public static func pending(_ facts: SetupFacts) -> [SetupStep] {
        SetupStep.allCases.filter { !isDone($0, facts) }
    }

    public static func needsAssistant(_ facts: SetupFacts, dismissed: Bool) -> Bool {
        !dismissed && pending(facts).contains { SetupStep.essential.contains($0) }
    }

    static func isDone(_ step: SetupStep, _ facts: SetupFacts) -> Bool {
        switch step {
        case .owner:
            let name = facts.ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
            return !name.isEmpty && name != Config.placeholderOwnerName
        case .aiEngine: return facts.engineVerified
        case .channel: return facts.channelConnected
        case .agents: return facts.enabledAgents > 0
        case .voice: return !facts.usesVoice || facts.voiceRecognition == .allowed
        case .notifications: return facts.notifications != .undecided
        }
    }
}
