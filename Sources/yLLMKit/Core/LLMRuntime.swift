public actor LLMRuntime {
    public let modelRegistry: ModelRegistry
    public let modelStore: any ModelStore

    private var backendsByID: [String: any LLMBackend]
    private var loadedModelsByID: [String: LoadedModel]

    public init(
        modelRegistry: ModelRegistry,
        modelStore: any ModelStore,
        backends: [any LLMBackend]
    ) throws {
        var backendsByID: [String: any LLMBackend] = [:]
        for backend in backends {
            guard backendsByID[backend.id] == nil else {
                throw LLMError.invalidRequest("Duplicate backend id: \(backend.id)")
            }
            backendsByID[backend.id] = backend
        }

        self.modelRegistry = modelRegistry
        self.modelStore = modelStore
        self.backendsByID = backendsByID
        self.loadedModelsByID = [:]
    }

    public func supportedModels() async -> [ModelDescriptor] {
        await modelRegistry.supportedModels()
    }

    public func localModels() async throws -> [LocalModel] {
        try await modelStore.localModels()
    }

    public func isModelInstalled(_ modelID: String) async throws -> Bool {
        try await modelStore.isModelInstalled(modelID)
    }

    public func downloadModel(id modelID: String) async throws -> AsyncThrowingStream<ModelDownloadProgress, Error> {
        let model = try await modelRegistry.model(id: modelID)
        let backend = try backend(for: model)
        return backend.downloadModel(ModelDownloadRequest(model: model))
    }

    public func downloadAndInstallModel(id modelID: String) async throws -> AsyncThrowingStream<ModelDownloadProgress, Error> {
        let model = try await modelRegistry.model(id: modelID)
        let backend = try backend(for: model)
        let downloadStream = backend.downloadModel(ModelDownloadRequest(model: model))

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await progress in downloadStream {
                        if progress.phase == .complete, let localModel = progress.localModel {
                            try await modelStore.register(localModel)
                        }
                        continuation.yield(progress)
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

    @discardableResult
    public func loadModel(id modelID: String) async throws -> LoadedModel {
        if let loadedModel = loadedModelsByID[modelID] {
            return loadedModel
        }

        let model = try await modelRegistry.model(id: modelID)
        let backend = try backend(for: model)
        let localModel = try await modelStore.localModel(for: modelID)
        let loadedModel = try await backend.loadModel(model, from: localModel)
        loadedModelsByID[modelID] = loadedModel
        return loadedModel
    }

    public func unloadModel(id modelID: String) async throws {
        let model = try await modelRegistry.model(id: modelID)
        let backend = try backend(for: model)
        try await backend.unloadModel(modelID)
        loadedModelsByID.removeValue(forKey: modelID)
    }

    public func createSession(
        modelID: String,
        configuration: SessionConfiguration
    ) async throws -> any LLMSession {
        let loadedModel = try loadedModel(id: modelID)
        guard loadedModel.model.capabilities.supportsChat else {
            throw LLMError.unsupportedCapability("Model does not support chat: \(modelID)")
        }

        let backend = try backend(for: loadedModel.model)
        return try await backend.createSession(
            model: loadedModel,
            configuration: configuration
        )
    }

    public func loadedModel(id modelID: String) throws -> LoadedModel {
        guard let loadedModel = loadedModelsByID[modelID] else {
            throw LLMError.modelNotLoaded(modelID)
        }
        return loadedModel
    }

    private func backend(for model: ModelDescriptor) throws -> any LLMBackend {
        guard let backend = backendsByID[model.backendID] else {
            throw LLMError.backendUnavailable(model.backendID)
        }
        return backend
    }
}
