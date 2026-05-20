public struct LLMPerformanceMetrics: Codable, Sendable, Equatable {
    public var modelID: String
    public var promptTokenCount: Int?
    public var outputTokenCount: Int?
    public var loadTimeSeconds: Double?
    public var firstTokenLatencySeconds: Double?
    public var totalGenerationSeconds: Double?
    public var tokensPerSecond: Double?
    public var wasWarm: Bool

    public init(
        modelID: String,
        promptTokenCount: Int? = nil,
        outputTokenCount: Int? = nil,
        loadTimeSeconds: Double? = nil,
        firstTokenLatencySeconds: Double? = nil,
        totalGenerationSeconds: Double? = nil,
        tokensPerSecond: Double? = nil,
        wasWarm: Bool
    ) {
        self.modelID = modelID
        self.promptTokenCount = promptTokenCount
        self.outputTokenCount = outputTokenCount
        self.loadTimeSeconds = loadTimeSeconds
        self.firstTokenLatencySeconds = firstTokenLatencySeconds
        self.totalGenerationSeconds = totalGenerationSeconds
        self.tokensPerSecond = tokensPerSecond
        self.wasWarm = wasWarm
    }
}
