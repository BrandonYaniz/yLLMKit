public struct LLMResponse: Codable, Sendable, Equatable {
    public var content: String
    public var finishReason: FinishReason
    public var tokens: [LLMToken]
    public var metrics: LLMPerformanceMetrics?
    public var metadata: [String: String]

    public init(
        content: String,
        finishReason: FinishReason,
        tokens: [LLMToken] = [],
        metrics: LLMPerformanceMetrics? = nil,
        metadata: [String: String] = [:]
    ) {
        self.content = content
        self.finishReason = finishReason
        self.tokens = tokens
        self.metrics = metrics
        self.metadata = metadata
    }
}
