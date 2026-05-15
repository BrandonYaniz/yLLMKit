import Foundation
import MLXLMCommon
import yLLMKit

public final class MLXSession: LLMSession, @unchecked Sendable {
    public let id: UUID
    public let model: ModelDescriptor

    private let session: ChatSession
    private let state = CancellationState()

    public init(
        id: UUID = UUID(),
        model: ModelDescriptor,
        container: ModelContainer,
        configuration: SessionConfiguration
    ) {
        self.id = id
        self.model = model
        self.session = ChatSession(
            container,
            instructions: configuration.systemPrompt,
            generateParameters: GenerateParameters(settings: model.defaultSettings)
        )
    }

    public func streamResponse(
        to messages: [LLMMessage],
        settings: GenerationSettings
    ) -> AsyncThrowingStream<LLMToken, Error> {
        AsyncThrowingStream { continuation in
            state.reset()
            let task = Task {
                do {
                    session.generateParameters = GenerateParameters(settings: settings)

                    var index = 0
                    let prompt = promptText(from: messages)
                    for try await chunk in session.streamResponse(to: prompt) {
                        if state.isCancelled || Task.isCancelled {
                            continuation.finish(throwing: LLMError.generationCancelled)
                            return
                        }

                        continuation.yield(
                            LLMToken(
                                text: chunk,
                                index: index
                            )
                        )
                        index += 1
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func cancel() {
        state.cancel()
    }

    private func promptText(from messages: [LLMMessage]) -> String {
        messages
            .filter { $0.role != .system }
            .map { message in
                switch message.role {
                case .user:
                    return "User: \(message.content)"
                case .assistant:
                    return "Assistant: \(message.content)"
                case .tool:
                    return "Tool: \(message.content)"
                case .system:
                    return message.content
                }
            }
            .joined(separator: "\n\n")
    }
}

private final class CancellationState: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.withLock {
            cancelled
        }
    }

    func cancel() {
        lock.withLock {
            cancelled = true
        }
    }

    func reset() {
        lock.withLock {
            cancelled = false
        }
    }
}

private extension GenerateParameters {
    init(settings: GenerationSettings) {
        self.init(
            maxTokens: settings.maxTokens,
            temperature: Float(settings.temperature),
            topP: Float(settings.topP),
            repetitionPenalty: settings.repetitionPenalty.map(Float.init)
        )
    }
}
