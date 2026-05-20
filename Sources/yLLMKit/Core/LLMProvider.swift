public protocol LLMProvider: Sendable {
    var providerID: LLMProviderID { get }

    func availableModels() async throws -> [LLMModelDescriptor]
    func prepareModel(_ modelID: LLMModelID) async throws
    func streamChat(request: LLMChatRequest) -> AsyncThrowingStream<LLMStreamEvent, Error>
}
