import Foundation

public extension LLMSession {
    func respond(
        to messages: [LLMMessage],
        settings: GenerationSettings
    ) async throws -> LLMResponse {
        let startedAt = Date()
        var firstTokenLatencySeconds: Double?
        var chunks: [String] = []
        var tokens: [LLMToken] = []

        for try await token in streamResponse(to: messages, settings: settings) {
            if firstTokenLatencySeconds == nil {
                firstTokenLatencySeconds = Date().timeIntervalSince(startedAt)
            }
            tokens.append(token)
            chunks.append(token.text)
        }

        let totalGenerationSeconds = Date().timeIntervalSince(startedAt)
        let outputTokenCount = tokens.count
        let tokensPerSecond = totalGenerationSeconds > 0
            ? Double(outputTokenCount) / totalGenerationSeconds
            : nil

        return LLMResponse(
            content: chunks.joined(),
            finishReason: .stop,
            tokens: tokens,
            metrics: LLMPerformanceMetrics(
                modelID: model.id,
                outputTokenCount: outputTokenCount,
                firstTokenLatencySeconds: firstTokenLatencySeconds,
                totalGenerationSeconds: totalGenerationSeconds,
                tokensPerSecond: tokensPerSecond,
                wasWarm: true
            )
        )
    }
}
