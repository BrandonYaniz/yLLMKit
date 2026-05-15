public extension LLMSession {
    func respond(
        to messages: [LLMMessage],
        settings: GenerationSettings
    ) async throws -> LLMResponse {
        var content = ""
        var tokens: [LLMToken] = []

        for try await token in streamResponse(to: messages, settings: settings) {
            tokens.append(token)
            content += token.text
        }

        return LLMResponse(
            content: content,
            finishReason: .stop,
            tokens: tokens
        )
    }
}
