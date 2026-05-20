public struct LLMModelDescriptor: Codable, Hashable, Sendable, Identifiable {
    public var id: LLMModelID
    public var displayName: String
    public var capabilities: LLMModelCapabilities
    public var defaultSettings: GenerationSettings?
    public var providerMetadata: [String: JSONValue]

    public init(
        id: LLMModelID,
        displayName: String,
        capabilities: LLMModelCapabilities,
        defaultSettings: GenerationSettings? = nil,
        providerMetadata: [String: JSONValue] = [:]
    ) {
        self.id = id
        self.displayName = displayName
        self.capabilities = capabilities
        self.defaultSettings = defaultSettings
        self.providerMetadata = providerMetadata
    }
}
