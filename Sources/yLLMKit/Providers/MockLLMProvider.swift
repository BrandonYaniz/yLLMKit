public struct MockLLMProvider: LLMProvider {
    public let providerID: LLMProviderID

    private let models: [LLMModelDescriptor]
    private let responseText: String

    public init(
        providerID: LLMProviderID = LLMProviderID(rawValue: "mock"),
        models: [LLMModelDescriptor],
        responseText: String = "mock response"
    ) {
        self.providerID = providerID
        self.models = models
        self.responseText = responseText
    }

    public func availableModels() async throws -> [LLMModelDescriptor] {
        models
    }

    public func prepareModel(_ modelID: LLMModelID) async throws {
        guard models.contains(where: { $0.id == modelID }) else {
            throw LLMProviderError.modelNotFound(modelID)
        }
    }

    public func streamChat(
        request: LLMChatRequest
    ) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            guard models.contains(where: { $0.id == request.modelID }) else {
                continuation.finish(throwing: LLMProviderError.modelNotFound(request.modelID))
                return
            }

            continuation.yield(.started(LLMStreamStart(modelID: request.modelID)))

            let text = responseText.truncated(atFirst: request.settings.stopSequences)
            let tokens = text.providerTokenDeltas()

            for token in tokens {
                continuation.yield(.textDelta(token))
            }

            continuation.yield(
                .completed(
                    LLMChatResponse(
                        modelID: request.modelID,
                        message: LLMMessage(role: .assistant, content: text),
                        usage: LLMUsage(outputTokens: tokens.count, totalTokens: tokens.count),
                        finishReason: .stop
                    )
                )
            )
            continuation.finish()
        }
    }
}

private extension String {
    func providerTokenDeltas() -> [String] {
        split(separator: " ", omittingEmptySubsequences: false)
            .enumerated()
            .map { index, chunk in
                index == 0 ? String(chunk) : " \(chunk)"
            }
    }

    func truncated(atFirst stopSequences: [String]) -> String {
        let stopRanges = stopSequences
            .filter { !$0.isEmpty }
            .compactMap { range(of: $0) }

        guard let firstStop = stopRanges.min(by: { $0.lowerBound < $1.lowerBound }) else {
            return self
        }
        return String(self[..<firstStop.lowerBound])
    }
}
