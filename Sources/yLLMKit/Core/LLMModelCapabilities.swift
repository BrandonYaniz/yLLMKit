public struct LLMModelCapabilities: Codable, Hashable, Sendable {
    public var supportsStreaming: Bool
    public var supportsLocalPreparation: Bool
    public var contextWindow: Int?
    public var maxOutputTokens: Int?

    public init(
        supportsStreaming: Bool,
        supportsLocalPreparation: Bool,
        contextWindow: Int? = nil,
        maxOutputTokens: Int? = nil
    ) {
        self.supportsStreaming = supportsStreaming
        self.supportsLocalPreparation = supportsLocalPreparation
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
    }
}
