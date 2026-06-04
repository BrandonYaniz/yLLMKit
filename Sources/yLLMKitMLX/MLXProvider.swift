import Foundation
import yLLMKit

public final class MLXProvider: LocalLLMProvider, @unchecked Sendable {
    public let providerID = LLMProviderID(rawValue: "mlx")

    private let backend: MLXBackend
    private let modelStore: (any ModelStore)?

    public init(
        backend: MLXBackend = MLXBackend(),
        modelStore: (any ModelStore)? = nil
    ) {
        self.backend = backend
        self.modelStore = modelStore
    }

    public func availableModels() async throws -> [LLMModelDescriptor] {
        try await backend.availableModels().map { $0.llmModelDescriptor(providerID: providerID) }
    }

    public func prepareModel(_ modelID: LLMModelID) async throws {
        for try await _ in prepareModelWithProgress(modelID) {}
    }

    public func localModels() async throws -> [LocalModel] {
        if let modelStore {
            return try await modelStore.localModels()
        }
        return try await backend.localModels()
    }

    public func isModelPrepared(_ modelID: LLMModelID) async throws -> Bool {
        let model = try await legacyModel(for: modelID)
        if try await backend.isModelPrepared(model.id) {
            return true
        }
        if let modelStore {
            return try await modelStore.isModelInstalled(model.id)
        }
        return false
    }

    public func prepareModelWithProgress(
        _ modelID: LLMModelID
    ) -> AsyncThrowingStream<ModelDownloadProgress, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let model = try await legacyModel(for: modelID)
                    let stream = await backend.downloadAndWarmModel(ModelDownloadRequest(model: model))

                    do {
                        for try await progress in stream {
                            if progress.phase == .complete, let localModel = progress.localModel {
                                try await modelStore?.register(localModel)
                            }
                            continuation.yield(progress)
                        }
                        continuation.finish()
                    } catch let error as LLMProviderError {
                        continuation.finish(throwing: error)
                    } catch is CancellationError {
                        continuation.finish(throwing: LLMProviderError.cancelled)
                    } catch {
                        continuation.finish(throwing: LLMProviderError.providerFailed(String(describing: error)))
                    }
                } catch let error as LLMProviderError {
                    continuation.finish(throwing: error)
                } catch is CancellationError {
                    continuation.finish(throwing: LLMProviderError.cancelled)
                } catch {
                    continuation.finish(throwing: LLMProviderError.providerFailed(String(describing: error)))
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func unloadModel(_ modelID: LLMModelID) async throws {
        let model = try await legacyModel(for: modelID)
        try await backend.unloadModel(model.id)
    }

    public func removeModel(_ modelID: LLMModelID) async throws {
        let model = try await legacyModel(for: modelID)
        try await backend.removeModel(model.id)
        try await modelStore?.removeModel(id: model.id)
    }

    public func streamChat(
        request: LLMChatRequest
    ) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let model = try await legacyModel(for: request.modelID)
                    let localModel = try await localModel(for: model.id)
                    if !(try await backend.isModelPrepared(model.id)) {
                        _ = try await backend.loadModel(model, from: localModel)
                    }
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
                } catch LLMError.generationCancelled {
                    continuation.finish(throwing: LLMProviderError.cancelled)
                } catch let error as LLMProviderError {
                    continuation.finish(throwing: error)
                } catch is CancellationError {
                    continuation.finish(throwing: LLMProviderError.cancelled)
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

    private func localModel(for modelID: String) async throws -> LocalModel? {
        if let modelStore {
            return try await modelStore.localModel(for: modelID)
        }
        return try await backend.localModels()
            .first { $0.modelID == modelID }
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
