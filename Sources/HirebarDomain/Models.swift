import Foundation

public enum Fit: String, Codable, Sendable {
    case strong = "ENCAJA"
    case stretch = "RETO"

    public var rank: Int { self == .strong ? 0 : 1 }
}

public enum Mode: String, Codable, CaseIterable, Sendable {
    case freelance = "freelance"
    case jobs = "empleo"
    case followUp = "seguimiento"
    case weeklyReport = "semanal"
    case prospecting = "prospeccion"
    case prospectingSend = "prospeccion-envio"
    case social = "redes"
    case linkedInDraft = "linkedin-borrador"
    case linkedInPublish = "linkedin-publicar"
    case profileUpdate = "perfil"
    case portalScanJobs = "portales-empleo"
    case portalScanFreelance = "portales-freelance"
    case followUpSend = "seguimiento-envio"

    public var batchPrefix: String {
        switch self {
        case .freelance: return "f"
        case .jobs: return "e"
        case .weeklyReport: return "s"
        case .linkedInDraft, .linkedInPublish: return "l"
        case .social: return "r"
        case .prospecting, .prospectingSend: return "p"
        case .followUp: return "g"
        case .profileUpdate: return "h"
        case .portalScanJobs: return "pe"
        case .portalScanFreelance: return "pf"
        case .followUpSend: return "gs"
        }
    }

    public var hasItems: Bool { self == .freelance || self == .jobs || self == .followUpSend }

    public var title: String {
        switch self {
        case .freelance: return "Enviar propuestas"
        case .jobs: return "Postular a vacantes"
        case .followUp: return "Seguimientos de propuestas"
        case .weeklyReport: return "Análisis semanal"
        case .prospecting: return "Buscar empresas y negocios"
        case .prospectingSend: return "Enviar correos aprobados"
        case .social: return "Buscar vacantes en redes"
        case .linkedInDraft: return "Preparar publicaciones"
        case .linkedInPublish: return "Publicar en redes"
        case .profileUpdate: return "Actualizar perfil y hojas de vida"
        case .portalScanJobs: return "Revisar tus portales de empleo"
        case .portalScanFreelance: return "Revisar tus portales freelance"
        case .followUpSend: return "Enviar seguimientos aprobados"
        }
    }
}

public enum BatchStatus: String, Codable, Sendable {
    case pending = "pendiente"
    case running = "en curso"
    case done = "hecho"
    case discarded = "descartado"
    case failed = "error"
    case interrupted = "interrumpido"
}

public struct Hit: Sendable {
    public let id: String
    public let platform: String
    public let fit: Fit
    public let title: String
    public let url: String
    public let detail: String
    public let score: Int

    public init(id: String, platform: String, fit: Fit, title: String, url: String, detail: String, score: Int) {
        self.id = id
        self.platform = platform
        self.fit = fit
        self.title = title
        self.url = url
        self.detail = detail
        self.score = score
    }

    public func with(fit: Fit? = nil, detail: String? = nil, score: Int? = nil) -> Hit {
        Hit(id: id, platform: platform, fit: fit ?? self.fit, title: title, url: url,
            detail: detail ?? self.detail, score: score ?? self.score)
    }

    public static func ranked(_ a: Hit, _ b: Hit) -> Bool {
        (a.fit.rank, a.score) < (b.fit.rank, b.score)
    }
}

public struct BatchItem: Codable, Sendable {
    public var id: String
    public var platform: String
    public var kind: String
    public var title: String
    public var url: String
    public var detail: String

    public init(_ hit: Hit) {
        id = hit.id
        platform = hit.platform
        kind = hit.fit.rawValue
        title = hit.title
        url = hit.url
        detail = hit.detail
    }
}

public struct Batch: Codable, Sendable {
    public var id: String
    public var mode: Mode
    public var created: Date
    public var items: [BatchItem]
    public var status: BatchStatus
    public var messageId: Int?
    public var result: String?
    /// Cuenta de contenido (solo para publicaciones).
    public var account: String?

    public init(mode: Mode, items: [BatchItem] = [], status: BatchStatus, manual: Bool = false, account: String? = nil) {
        self.id = Batch.newId(mode.batchPrefix + (manual ? "m" : "")) + (account.map { "-\($0)" } ?? "")
        self.mode = mode
        self.created = Date()
        self.items = items
        self.status = status
        self.account = account
    }

    static let uniqueSuffixLength = 4

    public static func newId(_ prefix: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let suffix = UUID().uuidString.prefix(uniqueSuffixLength).lowercased()
        return "\(prefix)-\(formatter.string(from: Date()))-\(suffix)"
    }

    public var isManual: Bool { id.split(separator: "-").first?.hasSuffix("m") ?? false }
}

extension BatchItem {
    public init(_ proposal: Proposal, kind label: String? = nil) {
        id = proposal.id
        platform = proposal.source
        kind = label ?? (proposal.fit ?? .strong).rawValue
        title = proposal.title
        url = proposal.target.displayText
        detail = [proposal.source, proposal.text].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
