import Foundation
import yLLMKit

public final class MLXProvider: LLMProvider, @unchecked Sendable {
    public let providerID = LLMProviderID(rawValue: "mlx")

    private let backend: MLXBackend

    public init(
        backend: MLXBackend = MLXBackend()
    ) {
        self.backend = backend
    }

    public func availableModels() async throws -> [LLMModelDescriptor] {
        try await backend.availableModels().map { $0.llmModelDescriptor(providerID: providerID) }
    }

    public func prepareModel(_ modelID: LLMModelID) async throws {
        let model = try await legacyModel(for: modelID)
        let stream = await backend.downloadAndWarmModel(ModelDownloadRequest(model: model))

        do {
            for try await _ in stream {}
        } catch {
            throw LLMProviderError.providerFailed(String(describing: error))
        }
    }

    public func streamChat(
        request: LLMChatRequest
    ) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let model = try await legacyModel(for: request.modelID)
                    let localModel = try await backend.localModels()
                        .first { $0.modelID == model.id }
                    let session = try await backend.createSession(
                        model: LoadedModel(model: model, localModel: localModel),
                        configuration: SessionConfiguration(systemPrompt: nil)
                    )

                    continuation.yield(.started(LLMStreamStart(modelID: request.modelID)))

                    var output = ""
                    var outputTokens = 0
                    for try await token in session.streamResponse(
                        to: request.messages,
                        settings: request.settings
                    ) {
                        output += token.text
                        outputTokens += 1
                        continuation.yield(.textDelta(token.text))
                    }

                    continuation.yield(
                        .completed(
                            LLMChatResponse(
                                modelID: request.modelID,
                                message: LLMMessage(role: .assistant, content: output),
                                usage: LLMUsage(
                                    outputTokens: outputTokens,
                                    totalTokens: outputTokens
                                ),
                                finishReason: .stop
                            )
                        )
                    )
                    continuation.finish()
                } catch LLMError.modelNotLoaded {
                    continuation.finish(throwing: LLMProviderError.modelNotPrepared(request.modelID))
                } catch let error as LLMProviderError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: LLMProviderError.providerFailed(String(describing: error)))
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func legacyModel(for modelID: LLMModelID) async throws -> ModelDescriptor {
        guard modelID.providerID == providerID else {
            throw LLMProviderError.modelNotFound(modelID)
        }

        let models = try await backend.availableModels()
        guard let model = models.first(where: { $0.id == modelID.modelName }) else {
            throw LLMProviderError.modelNotFound(modelID)
        }
        return model
    }
}

private extension ModelDescriptor {
    func llmModelDescriptor(providerID: LLMProviderID) -> LLMModelDescriptor {
        var metadata: [String: JSONValue] = [
            "provider": .string(provider),
            "repository": .string(repository)
        ]

        if let revision {
            metadata["revision"] = .string(revision)
        }
        if let recommendedRAMGB {
            metadata["recommendedRAMGB"] = .number(Double(recommendedRAMGB))
        }

        return LLMModelDescriptor(
            id: LLMModelID(providerID: providerID, modelName: id),
            displayName: displayName,
            capabilities: LLMModelCapabilities(
                supportsStreaming: capabilities.supportsChat,
                supportsLocalPreparation: true,
                contextWindow: capabilities.contextWindow,
                maxOutputTokens: capabilities.preferredMaxOutputTokens
            ),
            defaultSettings: defaultSettings,
            providerMetadata: metadata
        )
    }
}
