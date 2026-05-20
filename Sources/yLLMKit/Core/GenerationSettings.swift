public struct GenerationSettings: Codable, Sendable, Hashable {
    public var temperature: Double
    public var topP: Double
    public var maxTokens: Int?
    public var repetitionPenalty: Double?
    public var stopSequences: [String]

    public var maxOutputTokens: Int? {
        get { maxTokens }
        set { maxTokens = newValue }
    }

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

    public init(
        temperature: Double,
        topP: Double,
        maxOutputTokens: Int?,
        stopSequences: [String] = []
    ) {
        self.init(
            temperature: temperature,
            topP: topP,
            maxTokens: maxOutputTokens,
            repetitionPenalty: nil,
            stopSequences: stopSequences
        )
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
