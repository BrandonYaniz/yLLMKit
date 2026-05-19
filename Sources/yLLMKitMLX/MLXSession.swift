import Foundation
import MLXLMCommon
import yLLMKit

public final class MLXSession: LLMSession, @unchecked Sendable {
    public let id: UUID
    public let model: ModelDescriptor

    private let container: ModelContainer
    private let baseInstructions: String?
    private let state = CancellationState()

    public init(
        id: UUID = UUID(),
        model: ModelDescriptor,
        container: ModelContainer,
        configuration: SessionConfiguration
    ) {
        self.id = id
        self.model = model
        self.container = container
        self.baseInstructions = configuration.systemPrompt
    }

    public func streamResponse(
        to messages: [LLMMessage],
        settings: GenerationSettings
    ) -> AsyncThrowingStream<LLMToken, Error> {
        AsyncThrowingStream { continuation in
            state.reset()
            let task = Task {
                do {
                    var index = 0
                    let request = try MLXPromptBuilder.promptRequest(from: messages)
                    let session = ChatSession(
                        container,
                        instructions: combinedInstructions(request.instructions),
                        history: request.history,
                        generateParameters: GenerateParameters(settings: settings)
                    )

                    for try await chunk in session.streamResponse(
                        to: request.prompt.content,
                        role: request.prompt.role,
                        images: [],
                        videos: []
                    ) {
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

    private func combinedInstructions(_ requestInstructions: String?) -> String? {
        [baseInstructions, requestInstructions]
            .compactMap { value in
                value?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
            .nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
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
