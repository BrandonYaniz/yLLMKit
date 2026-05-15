public struct ModelCapabilities: Codable, Sendable, Equatable {
    public var supportsChat: Bool
    public var supportsCompletion: Bool
    public var supportsVision: Bool
    public var supportsEmbeddings: Bool
    public var supportsToolCalling: Bool
    public var supportsJSONMode: Bool
    public var contextWindow: Int
    public var preferredMaxOutputTokens: Int?

    public init(
        supportsChat: Bool,
        supportsCompletion: Bool,
        supportsVision: Bool,
        supportsEmbeddings: Bool,
        supportsToolCalling: Bool,
        supportsJSONMode: Bool,
        contextWindow: Int,
        preferredMaxOutputTokens: Int? = nil
    ) {
        self.supportsChat = supportsChat
        self.supportsCompletion = supportsCompletion
        self.supportsVision = supportsVision
        self.supportsEmbeddings = supportsEmbeddings
        self.supportsToolCalling = supportsToolCalling
        self.supportsJSONMode = supportsJSONMode
        self.contextWindow = contextWindow
        self.preferredMaxOutputTokens = preferredMaxOutputTokens
    }

    public static func chatOnly(
        contextWindow: Int,
        preferredMaxOutputTokens: Int? = nil
    ) -> ModelCapabilities {
        ModelCapabilities(
            supportsChat: true,
            supportsCompletion: false,
            supportsVision: false,
            supportsEmbeddings: false,
            supportsToolCalling: false,
            supportsJSONMode: false,
            contextWindow: contextWindow,
            preferredMaxOutputTokens: preferredMaxOutputTokens
        )
    }
}
