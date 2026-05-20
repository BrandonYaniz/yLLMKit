public struct LLMUsage: Codable, Hashable, Sendable {
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var totalTokens: Int?

    public init(
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        totalTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
    }
}
