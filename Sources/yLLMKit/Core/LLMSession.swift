import Foundation

public protocol LLMSession: Sendable {
    var id: UUID { get }
    var model: ModelDescriptor { get }

    func respond(
        to messages: [LLMMessage],
        settings: GenerationSettings
    ) async throws -> LLMResponse

    func streamResponse(
        to messages: [LLMMessage],
        settings: GenerationSettings
    ) -> AsyncThrowingStream<LLMToken, Error>

    func cancel()
}
