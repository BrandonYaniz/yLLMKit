public struct ModelDescriptor: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var displayName: String
    public var backendID: String
    public var provider: String
    public var repository: String
    public var revision: String?
    public var capabilities: ModelCapabilities
    public var recommendedRAMGB: Int?
    public var defaultSettings: GenerationSettings

    public init(
        id: String,
        displayName: String,
        backendID: String,
        provider: String,
        repository: String,
        revision: String? = nil,
        capabilities: ModelCapabilities,
        recommendedRAMGB: Int? = nil,
        defaultSettings: GenerationSettings
    ) {
        self.id = id
        self.displayName = displayName
        self.backendID = backendID
        self.provider = provider
        self.repository = repository
        self.revision = revision
        self.capabilities = capabilities
        self.recommendedRAMGB = recommendedRAMGB
        self.defaultSettings = defaultSettings
    }
}
