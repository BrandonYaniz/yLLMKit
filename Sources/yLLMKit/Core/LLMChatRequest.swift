public struct LLMChatRequest: Codable, Hashable, Sendable {
    public var modelID: LLMModelID
    public var messages: [LLMMessage]
    public var settings: GenerationSettings
    public var providerOptions: LLMProviderOptions

    public init(
        modelID: LLMModelID,
        messages: [LLMMessage],
        settings: GenerationSettings = .balanced,
        providerOptions: LLMProviderOptions = .empty
    ) {
        self.modelID = modelID
        self.messages = messages
        self.settings = settings
        self.providerOptions = providerOptions
    }
}
