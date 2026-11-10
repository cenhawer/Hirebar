
public struct AI: Sendable {
    public let settings: AIEngineSettings

    public init(settings: AIEngineSettings) {
        self.settings = settings
    }

    public var name: String { settings.displayName }
    public var capitalizedName: String { name.prefix(1).uppercased() + name.dropFirst() }
}
