import Foundation

public enum AgentKind: String, Codable, CaseIterable, Sendable {
    case jobs = "empleo"
    case freelance = "freelance"
    case clients = "clientes"
    case content = "contenido"
    case profile = "perfil"
    case analyst = "analista"

    public static func parse(_ text: String) -> AgentKind? {
        switch TextTools.normalize(text).trimmingCharacters(in: .whitespaces) {
        case "empleo", "empleos", "trabajo", "trabajos": return .jobs
        case "freelance", "freelancer", "propuestas": return .freelance
        case "clientes", "cliente", "correos", "prospeccion": return .clients
        case "contenido", "redes sociales", "publicaciones", "posts": return .content
        case "perfil", "hv": return .profile
        case "analista", "informe", "analisis": return .analyst
        default: return named(text)
        }
    }

    static func named(_ text: String) -> AgentKind? {
        let wanted = TextTools.normalize(text).trimmingCharacters(in: .whitespaces)
        guard !wanted.isEmpty else { return nil }
        return allCases.first { TextTools.normalize(AgentStore.load($0).name).trimmingCharacters(in: .whitespaces) == wanted }
    }

    public static func owner(of mode: Mode) -> AgentKind {
        switch mode {
        case .jobs, .social, .portalScanJobs: return .jobs
        case .freelance, .followUp, .followUpSend, .portalScanFreelance: return .freelance
        case .prospecting, .prospectingSend: return .clients
        case .linkedInDraft, .linkedInPublish: return .content
        case .profileUpdate: return .profile
        case .weeklyReport: return .analyst
        }
    }
}

public struct AgentTask: Codable, Sendable, Equatable {
    public var mode: Mode
    public var hours: [Int]
    public var days: [String]
    public var windowHours: Int

    static let dayNames = ["dom", "lun", "mar", "mie", "jue", "vie", "sab"]

    public init(mode: Mode, hours: [Int], days: [String] = ["todos"], windowHours: Int = 1) {
        self.mode = mode
        self.hours = hours
        self.days = days
        self.windowHours = windowHours
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = try c.decode(Mode.self, forKey: .mode)
        hours = try c.decodeIfPresent([Int].self, forKey: .hours) ?? []
        days = try c.decodeIfPresent([String].self, forKey: .days) ?? ["todos"]
        windowHours = max(1, try c.decodeIfPresent(Int.self, forKey: .windowHours) ?? 1)
    }

    public func runs(onWeekday weekday: Int) -> Bool {
        let wanted = days.map { TextTools.normalize($0).trimmingCharacters(in: .whitespaces) }
        if wanted.contains("todos") { return true }
        if wanted.contains("habiles") && (2...6).contains(weekday) { return true }
        guard (1...7).contains(weekday) else { return false }
        return wanted.contains(Self.dayNames[weekday - 1])
    }

    public func dueSlot(at now: Date, calendar: Calendar = .current) -> (day: Date, hour: Int)? {
        for offset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now)),
                  runs(onWeekday: calendar.component(.weekday, from: day)) else { continue }
            for hour in hours.sorted(by: >) {
                guard let start = calendar.date(byAdding: .hour, value: hour, to: day) else { continue }
                let end = start.addingTimeInterval(TimeInterval(windowHours * 3600))
                if now >= start && now < end { return (day, hour) }
            }
        }
        return nil
    }

    public func nextStart(after now: Date, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  runs(onWeekday: calendar.component(.weekday, from: day)) else { continue }
            for hour in hours.sorted() {
                if let start = calendar.date(byAdding: .hour, value: hour, to: day), start > now { return start }
            }
        }
        return nil
    }

    public var scheduleText: String {
        let dayText: String
        if days.contains("todos") {
            dayText = "todos los días"
        } else if days.contains("habiles") {
            dayText = "lun a vie"
        } else {
            dayText = days.joined(separator: ", ")
        }
        let hourText = hours.sorted().map { $0 == 12 ? "12 m." : $0 < 12 ? "\($0) a. m." : "\($0 - 12) p. m." }.joined(separator: ", ")
        return "\(dayText) · \(hourText)"
    }
}

public struct AgentSettings: Codable, Sendable {
    public var id: AgentKind
    public var name: String
    public var purpose: String
    public var enabled: Bool
    public var autoApprove: Bool
    public var searchEveryMinutes: Int?
    public var dailyLimit: Int?
    public var tasks: [AgentTask]

    public init(id: AgentKind, name: String, purpose: String, enabled: Bool = true, autoApprove: Bool = false,
                searchEveryMinutes: Int? = nil, dailyLimit: Int? = nil, tasks: [AgentTask] = []) {
        self.id = id
        self.name = name
        self.purpose = purpose
        self.enabled = enabled
        self.autoApprove = autoApprove
        self.searchEveryMinutes = searchEveryMinutes
        self.dailyLimit = dailyLimit
        self.tasks = tasks
    }

    enum CodingKeys: String, CodingKey {
        case id, name, purpose, enabled, autoApprove, searchEveryMinutes, dailyLimit, tasks
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(AgentKind.self, forKey: .id)
        let base = AgentSettings.defaults(for: id)
        self.id = id
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? base.name
        purpose = try c.decodeIfPresent(String.self, forKey: .purpose) ?? base.purpose
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? base.enabled
        autoApprove = try c.decodeIfPresent(Bool.self, forKey: .autoApprove) ?? base.autoApprove
        searchEveryMinutes = try c.decodeIfPresent(Int.self, forKey: .searchEveryMinutes) ?? base.searchEveryMinutes
        dailyLimit = try c.decodeIfPresent(Int.self, forKey: .dailyLimit) ?? base.dailyLimit
        tasks = try c.decodeIfPresent([AgentTask].self, forKey: .tasks) ?? base.tasks
    }

    public var hasSearch: Bool { id == .jobs || id == .freelance }

    public static func portalScanMode(for kind: AgentKind) -> Mode? {
        switch kind {
        case .jobs: return .portalScanJobs
        case .freelance: return .portalScanFreelance
        default: return nil
        }
    }

    public mutating func ensurePortalScanTask() {
        guard let mode = Self.portalScanMode(for: id), !tasks.contains(where: { $0.mode == mode }) else { return }
        tasks.append(AgentTask(mode: mode, hours: [9, 13, 17]))
    }

    public func nextTaskStart(after now: Date = Date()) -> Date? {
        tasks.compactMap { $0.nextStart(after: now) }.min()
    }

    public static func defaults(for kind: AgentKind, config: Config = Config()) -> AgentSettings {
        switch kind {
        case .jobs:
            return AgentSettings(id: .jobs, name: "Empleo",
                                 purpose: "Busca vacantes en portales de empleo, postula y revisa publicaciones en redes.",
                                 enabled: config.jobsOn, autoApprove: config.autoJobs,
                                 searchEveryMinutes: config.jobMinutes, dailyLimit: 20,
                                 tasks: [AgentTask(mode: .social, hours: [8, 10, 12, 14, 16, 18, 20]),
                                         AgentTask(mode: .portalScanJobs, hours: [9, 13, 17])])
        case .freelance:
            return AgentSettings(id: .freelance, name: "Freelance",
                                 purpose: "Busca proyectos en portales freelance, envía propuestas y hace seguimientos.",
                                 enabled: config.freelanceOn, autoApprove: config.autoFreelance,
                                 searchEveryMinutes: config.freelanceMinutes, dailyLimit: 5,
                                 tasks: [AgentTask(mode: .followUp, hours: [10, 16], windowHours: 3),
                                         AgentTask(mode: .portalScanFreelance, hours: [9, 13, 17])])
        case .clients:
            return AgentSettings(id: .clients, name: "Clientes",
                                 purpose: "Busca empresas y negocios que necesitan software y les escribe por correo.",
                                 enabled: true, autoApprove: config.autoEmails, dailyLimit: 10,
                                 tasks: [AgentTask(mode: .prospecting, hours: [7], days: ["habiles"], windowHours: 12)])
        case .content:
            return AgentSettings(id: .content, name: "Contenido",
                                 purpose: "Prepara publicaciones para redes; nada se publica sin tu aprobación.",
                                 enabled: true, autoApprove: false,
                                 tasks: [AgentTask(mode: .linkedInDraft, hours: [9], days: ["todos"], windowHours: 12)])
        case .profile:
            return AgentSettings(id: .profile, name: "Perfil",
                                 purpose: "Mantiene tu perfil al día y regenera tus hojas de vida cuando se lo pides.",
                                 enabled: true, autoApprove: false)
        case .analyst:
            return AgentSettings(id: .analyst, name: "Analista",
                                 purpose: "Entrega el análisis semanal con las métricas de cada agente; no cambia nada.",
                                 enabled: true, autoApprove: false,
                                 tasks: [AgentTask(mode: .weeklyReport, hours: [18], days: ["dom"], windowHours: 30)])
        }
    }
}

public enum AgentStore {
    public static var folder: URL { Paths.workspace.appendingPathComponent("agentes", isDirectory: true) }

    public static func url(for kind: AgentKind) -> URL {
        folder.appendingPathComponent("\(kind.rawValue).json")
    }

    public static func load(_ kind: AgentKind) -> AgentSettings {
        guard let data = try? Data(contentsOf: url(for: kind)) else { return AgentSettings.defaults(for: kind, config: Config.load()) }
        do {
            var settings = try JSONDecoder().decode(AgentSettings.self, from: data)
            if kind == .content {
                // Los días de las publicaciones se eligen en cada cuenta; la tarea corre todos los días.
                settings.tasks = settings.tasks.map { task in
                    var task = task
                    if task.mode == .linkedInDraft { task.days = ["todos"] }
                    return task
                }
            }
            return settings
        } catch {
            Log.write("agentes/\(kind.rawValue).json tiene un error (\(error.localizedDescription)); se usa la configuración por defecto")
            return AgentSettings.defaults(for: kind, config: Config.load())
        }
    }

    public static func all() -> [AgentSettings] { AgentKind.allCases.map(load) }

    public static func save(_ settings: AgentSettings) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(settings) { try? data.write(to: url(for: settings.id), options: .atomic) }
    }

    public static func update(_ kind: AgentKind, _ change: (inout AgentSettings) -> Void) {
        var settings = load(kind)
        change(&settings)
        save(settings)
    }

    public static func writeMissingDefaults() {
        let config = Config.load()
        for kind in AgentKind.allCases where !FileManager.default.fileExists(atPath: url(for: kind).path) {
            save(AgentSettings.defaults(for: kind, config: config))
        }
    }
}
