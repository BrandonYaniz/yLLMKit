public struct LLMStreamStart: Codable, Hashable, Sendable {
    public var modelID: LLMModelID
    public var providerMetadata: [String: String]

    public init(modelID: LLMModelID, providerMetadata: [String: String] = [:]) {
        self.modelID = modelID
        self.providerMetadata = providerMetadata
    }
}

public enum LLMStreamEvent: Codable, Hashable, Sendable {
    case started(LLMStreamStart)
    case textDelta(String)
    case completed(LLMChatResponse)
}
