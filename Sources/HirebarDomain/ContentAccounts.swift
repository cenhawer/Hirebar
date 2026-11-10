import Foundation

public enum ContentNetwork: String, Codable, CaseIterable, Sendable {
    case linkedin
    case instagram

    public var title: String { self == .linkedin ? "LinkedIn" : "Instagram" }
}

public struct ContentPalette: Codable, Equatable, Sendable {
    public var background: String
    public var surface: String
    public var accent: String
    public var text: String
    public var muted: String

    public init(background: String, surface: String, accent: String, text: String, muted: String) {
        self.background = background
        self.surface = surface
        self.accent = accent
        self.text = text
        self.muted = muted
    }
}

public struct PalettePreset: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let palette: ContentPalette
    public let style: String
}

public extension PalettePreset {
    static let all: [PalettePreset] = [
        PalettePreset(id: "negro-naranja", title: "Negro y naranja",
                      palette: ContentPalette(background: "#0D0D0D", surface: "#1A1A1A", accent: "#F07C32",
                                              text: "#F5F1EA", muted: "#9A9A9A"),
                      style: "Titulares grandes en sans serif blanca con la palabra clave en naranja o en serif cursiva naranja (Georgia italic). Etiquetas pequeñas en minúscula con letra monoespaciada, y una pastilla naranja con texto monoespaciado arriba a la izquierda."),
        PalettePreset(id: "azul-noche", title: "Azul noche",
                      palette: ContentPalette(background: "#0B1220", surface: "#16213A", accent: "#4F8CFF",
                                              text: "#F1F5FF", muted: "#94A3B8"),
                      style: "Titulares grandes en sans serif con la palabra clave en el color de acento. Tarjetas con esquinas redondeadas sobre el fondo."),
        PalettePreset(id: "claro-azul", title: "Claro con azul",
                      palette: ContentPalette(background: "#FFFFFF", surface: "#F1F4F9", accent: "#1F5EFF",
                                              text: "#0F172A", muted: "#64748B"),
                      style: "Fondo claro, titulares negros y gruesos, subrayado o resaltado en el color de acento. Mucho espacio en blanco."),
        PalettePreset(id: "verde", title: "Verde",
                      palette: ContentPalette(background: "#0E1A14", surface: "#18291F", accent: "#3DDC84",
                                              text: "#F0FFF6", muted: "#8FB3A0"),
                      style: "Titulares grandes en sans serif, detalles con líneas y la palabra clave en verde."),
    ]

    static var standard: PalettePreset { all[1] }
}

public struct ContentAccount: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var enabled: Bool
    public var network: ContentNetwork
    public var name: String
    public var tagline: String
    public var handle: String
    public var focus: String
    public var style: String
    public var palette: ContentPalette
    public var days: [String]
    public var video: Bool
    public var captions: Bool

    public static let defaultIdentifier = "personal"

    public init(id: String, enabled: Bool = true, network: ContentNetwork = .linkedin, name: String = "",
                tagline: String = "", handle: String = "", focus: String = ContentAccount.defaultFocus,
                style: String = PalettePreset.standard.style, palette: ContentPalette = PalettePreset.standard.palette,
                days: [String] = ["mar", "jue"], video: Bool = false, captions: Bool = true) {
        self.id = id
        self.enabled = enabled
        self.network = network
        self.name = name
        self.tagline = tagline
        self.handle = handle
        self.focus = focus
        self.style = style
        self.palette = palette
        self.days = days
        self.video = video
        self.captions = captions
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = ContentAccount(id: try c.decode(String.self, forKey: .id))
        id = base.id
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? base.enabled
        network = try c.decodeIfPresent(ContentNetwork.self, forKey: .network) ?? base.network
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? base.name
        tagline = try c.decodeIfPresent(String.self, forKey: .tagline) ?? base.tagline
        handle = try c.decodeIfPresent(String.self, forKey: .handle) ?? base.handle
        focus = try c.decodeIfPresent(String.self, forKey: .focus) ?? base.focus
        style = try c.decodeIfPresent(String.self, forKey: .style) ?? base.style
        palette = try c.decodeIfPresent(ContentPalette.self, forKey: .palette) ?? base.palette
        days = try c.decodeIfPresent([String].self, forKey: .days) ?? base.days
        video = try c.decodeIfPresent(Bool.self, forKey: .video) ?? base.video
        captions = try c.decodeIfPresent(Bool.self, forKey: .captions) ?? base.captions
    }

    public static let defaultFocus = "Consejos de tecnología para negocios, mitos del software, noticias de la semana y buenas prácticas para desarrolladores. Para dueños de negocio, emprendedores y otros desarrolladores."

    public var title: String {
        let label = name.trimmingCharacters(in: .whitespaces).isEmpty ? id : name
        return "\(label) (\(network.title))"
    }

    public func runs(on date: Date, calendar: Calendar = .current) -> Bool {
        AgentTask(mode: .linkedInDraft, hours: [], days: days).runs(onWeekday: calendar.component(.weekday, from: date))
    }
}
