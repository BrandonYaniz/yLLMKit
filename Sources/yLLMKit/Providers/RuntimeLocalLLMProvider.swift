public struct RuntimeLocalLLMProvider: LocalLLMProvider {
    public let providerID: LLMProviderID

    private let runtime: LLMRuntime
    private let backendID: String?

    public init(
        providerID: LLMProviderID = LLMProviderID(rawValue: "local"),
        runtime: LLMRuntime,
        backendID: String? = nil
    ) {
        self.providerID = providerID
        self.runtime = runtime
        self.backendID = backendID
    }

    public func availableModels() async throws -> [LLMModelDescriptor] {
        await runtime.supportedModels()
            .filter(matchesConfiguredBackend)
            .map { $0.llmModelDescriptor(providerID: providerID) }
    }

    public func prepareModel(_ modelID: LLMModelID) async throws {
        let runtimeModelID = try await runtimeModelID(for: modelID)
        do {
            let stream = try await runtime.downloadAndInstallModel(id: runtimeModelID)
            for try await _ in stream {}
        } catch {
            throw mapRuntimeError(error, modelID: modelID)
        }
    }

    public func localModels() async throws -> [LocalModel] {
        let models = try await runtime.localModels()
        guard let backendID else {
            return models
        }
        return models.filter { $0.backendID == backendID }
    }

    public func isModelPrepared(_ modelID: LLMModelID) async throws -> Bool {
        let runtimeModelID = try await runtimeModelID(for: modelID)
        do {
            return try await runtime.isModelInstalled(runtimeModelID)
        } catch {
            throw mapRuntimeError(error, modelID: modelID)
        }
    }

    public func prepareModelWithProgress(
        _ modelID: LLMModelID
    ) -> AsyncThrowingStream<ModelDownloadProgress, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let runtimeModelID = try await runtimeModelID(for: modelID)
                    let stream = try await runtime.downloadAndInstallModel(id: runtimeModelID)
                    for try await progress in stream {
                        continuation.yield(progress)
                    }
                    continuation.finish()
                } catch let error as LLMProviderError {
                    continuation.finish(throwing: error)
                } catch is CancellationError {
                    continuation.finish(throwing: LLMProviderError.cancelled)
                } catch {
                    continuation.finish(throwing: mapRuntimeError(error, modelID: modelID))
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func unloadModel(_ modelID: LLMModelID) async throws {
        let runtimeModelID = try await runtimeModelID(for: modelID)
        do {
            try await runtime.unloadModel(id: runtimeModelID)
        } catch {
            throw mapRuntimeError(error, modelID: modelID)
        }
    }

    public func removeModel(_ modelID: LLMModelID) async throws {
        let runtimeModelID = try await runtimeModelID(for: modelID)
        do {
            try await runtime.removeModel(id: runtimeModelID)
        } catch {
            throw mapRuntimeError(error, modelID: modelID)
        }
    }

    public func streamChat(
        request: LLMChatRequest
    ) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let runtimeModelID = try await runtimeModelID(for: request.modelID)
                    _ = try await runtime.loadModel(id: runtimeModelID)
                    let session = try await runtime.createSession(
                        modelID: runtimeModelID,
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
                } catch let error as LLMProviderError {
                    continuation.finish(throwing: error)
                } catch is CancellationError {
                    continuation.finish(throwing: LLMProviderError.cancelled)
                } catch {
                    continuation.finish(throwing: mapRuntimeError(error, modelID: request.modelID))
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func runtimeModelID(for modelID: LLMModelID) async throws -> String {
        guard modelID.providerID == providerID else {
            throw LLMProviderError.modelNotFound(modelID)
        }

        guard await runtime.supportedModels()
            .filter(matchesConfiguredBackend)
            .contains(where: { $0.id == modelID.modelName }) else {
            throw LLMProviderError.modelNotFound(modelID)
        }

        return modelID.modelName
    }

    private func matchesConfiguredBackend(_ model: ModelDescriptor) -> Bool {
        guard let backendID else {
            return true
        }
        return model.backendID == backendID
    }
}

private extension ModelDescriptor {
    func llmModelDescriptor(providerID: LLMProviderID) -> LLMModelDescriptor {
        var metadata: [String: JSONValue] = [
            "backendID": .string(backendID),
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

private func mapRuntimeError(_ error: Error, modelID: LLMModelID) -> LLMProviderError {
    switch error {
    case LLMError.modelNotFound:
        return .modelNotFound(modelID)
    case LLMError.modelNotInstalled, LLMError.modelNotLoaded:
        return .modelNotPrepared(modelID)
    case LLMError.unsupportedCapability(let message):
        return .unsupportedCapability(message)
    case LLMError.invalidRequest(let message):
        return .invalidRequest(message)
    case LLMError.generationCancelled:
        return .cancelled
    case LLMError.backendUnavailable(let backendID):
        return .providerFailed("Backend unavailable: \(backendID)")
    case LLMError.backendFailure(let message):
        return .providerFailed(message)
    default:
        return .providerFailed(String(describing: error))
    }
}
