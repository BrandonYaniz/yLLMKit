public struct LLMChatResponse: Codable, Hashable, Sendable {
    public var modelID: LLMModelID
    public var message: LLMMessage
    public var usage: LLMUsage?
    public var finishReason: LLMFinishReason?
    public var providerMetadata: [String: String]

    public init(
        modelID: LLMModelID,
        message: LLMMessage,
        usage: LLMUsage? = nil,
        finishReason: LLMFinishReason? = nil,
        providerMetadata: [String: String] = [:]
    ) {
        self.modelID = modelID
        self.message = message
        self.usage = usage
        self.finishReason = finishReason
        self.providerMetadata = providerMetadata
    }
}
