public struct LLMResponse: Codable, Sendable, Equatable {
    public var content: String
    public var finishReason: FinishReason
    public var tokens: [LLMToken]
    public var metadata: [String: String]

    public init(
        content: String,
        finishReason: FinishReason,
        tokens: [LLMToken] = [],
        metadata: [String: String] = [:]
    ) {
        self.content = content
        self.finishReason = finishReason
        self.tokens = tokens
        self.metadata = metadata
    }
}
