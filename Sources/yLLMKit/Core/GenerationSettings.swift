public struct GenerationSettings: Codable, Sendable, Hashable {
    public var temperature: Double?
    public var topP: Double?
    public var maxTokens: Int?
    public var stopSequences: [String]

    public var maxOutputTokens: Int? {
        get { maxTokens }
        set { maxTokens = newValue }
    }

    public init(
        temperature: Double? = nil,
        topP: Double? = nil,
        maxTokens: Int? = nil,
        stopSequences: [String] = []
    ) {
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.stopSequences = stopSequences
    }

    public init(
        temperature: Double? = nil,
        topP: Double? = nil,
        maxOutputTokens: Int?,
        stopSequences: [String] = []
    ) {
        self.init(
            temperature: temperature,
            topP: topP,
            maxTokens: maxOutputTokens,
            stopSequences: stopSequences
        )
    }

    public static let balanced = GenerationSettings(
        temperature: 0.7,
        topP: 0.9,
        maxTokens: nil,
        stopSequences: []
    )

    public static let precise = GenerationSettings(
        temperature: 0.2,
        topP: 0.8,
        maxTokens: nil,
        stopSequences: []
    )
}
