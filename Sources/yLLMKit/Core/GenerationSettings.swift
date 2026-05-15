public struct GenerationSettings: Codable, Sendable, Equatable {
    public var temperature: Double
    public var topP: Double
    public var maxTokens: Int?
    public var repetitionPenalty: Double?
    public var stopSequences: [String]

    public init(
        temperature: Double,
        topP: Double,
        maxTokens: Int? = nil,
        repetitionPenalty: Double? = nil,
        stopSequences: [String] = []
    ) {
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.repetitionPenalty = repetitionPenalty
        self.stopSequences = stopSequences
    }

    public static let balanced = GenerationSettings(
        temperature: 0.7,
        topP: 0.9,
        maxTokens: nil,
        repetitionPenalty: nil,
        stopSequences: []
    )

    public static let precise = GenerationSettings(
        temperature: 0.2,
        topP: 0.8,
        maxTokens: nil,
        repetitionPenalty: nil,
        stopSequences: []
    )
}
