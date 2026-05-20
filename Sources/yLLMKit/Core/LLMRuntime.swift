import Foundation

public actor LLMRuntime {
    public let modelRegistry: ModelRegistry
    public let modelStore: any ModelStore

    private var backendsByID: [String: any LLMBackend]
    private var loadedModelsByID: [String: LoadedModel]
    private var loadingModelsByID: [String: Task<LoadedModel, Error>]
    private var startingDownloadHubsByID: [
        String: Task<DownloadProgressHub, Error>
    ]
    private var downloadHubsByID: [String: DownloadProgressHub]

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
        self.loadingModelsByID = [:]
        self.startingDownloadHubsByID = [:]
        self.downloadHubsByID = [:]
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
        return await backend.downloadModel(ModelDownloadRequest(model: model))
    }

    public func downloadAndInstallModel(id modelID: String) async throws -> AsyncThrowingStream<ModelDownloadProgress, Error> {
        if let hub = downloadHubsByID[modelID] {
            return await hub.stream()
        }
        if let task = startingDownloadHubsByID[modelID] {
            let hub = try await task.value
            return await hub.stream()
        }

        let task = Task {
            try await startDownloadAndInstallModel(id: modelID)
        }
        startingDownloadHubsByID[modelID] = task

        do {
            let hub = try await task.value
            startingDownloadHubsByID[modelID] = nil
            return await hub.stream()
        } catch {
            startingDownloadHubsByID[modelID] = nil
            throw error
        }
    }

    private func startDownloadAndInstallModel(
        id modelID: String
    ) async throws -> DownloadProgressHub {
        let model = try await modelRegistry.model(id: modelID)
        let backend = try backend(for: model)
        let downloadStream = await backend.downloadModel(ModelDownloadRequest(model: model))
        let hub = DownloadProgressHub()
        downloadHubsByID[modelID] = hub

        Task {
            do {
                for try await progress in downloadStream {
                    if progress.phase == .complete, let localModel = progress.localModel {
                        try await modelStore.register(localModel)
                    }
                    await hub.yield(progress)
                }
                await hub.finish()
            } catch {
                await hub.finish(throwing: error)
            }
            clearDownloadHub(for: modelID, hub: hub)
        }

        return hub
    }

    @discardableResult
    public func loadModel(id modelID: String) async throws -> LoadedModel {
        if let loadedModel = loadedModelsByID[modelID] {
            return loadedModel
        }
        if let task = loadingModelsByID[modelID] {
            return try await task.value
        }

        let task = Task {
            try await loadModelFromStore(id: modelID)
        }
        loadingModelsByID[modelID] = task

        do {
            let loadedModel = try await task.value
            loadedModelsByID[modelID] = loadedModel
            loadingModelsByID[modelID] = nil
            return loadedModel
        } catch {
            loadingModelsByID[modelID] = nil
            throw error
        }
    }

    private func loadModelFromStore(id modelID: String) async throws -> LoadedModel {
        let model = try await modelRegistry.model(id: modelID)
        let backend = try backend(for: model)
        let localModel = try await modelStore.localModel(for: modelID)
        guard let localModel, try await modelStore.isModelInstalled(modelID) else {
            throw LLMError.modelNotInstalled(modelID)
        }

        return try await backend.loadModel(model, from: localModel)
    }

    public func unloadModel(id modelID: String) async throws {
        let model = try await modelRegistry.model(id: modelID)
        let backend = try backend(for: model)
        try await backend.unloadModel(modelID)
        loadedModelsByID.removeValue(forKey: modelID)
        loadingModelsByID[modelID]?.cancel()
        loadingModelsByID.removeValue(forKey: modelID)
    }

    public func removeModel(id modelID: String) async throws {
        if loadedModelsByID[modelID] != nil {
            try await unloadModel(id: modelID)
        }
        try await modelStore.removeModel(id: modelID)
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

    private func clearDownloadHub(for modelID: String, hub: DownloadProgressHub) {
        guard downloadHubsByID[modelID] === hub else {
            return
        }
        downloadHubsByID[modelID] = nil
    }
}

private actor DownloadProgressHub {
    private var continuations: [UUID: AsyncThrowingStream<ModelDownloadProgress, Error>.Continuation]
    private var replay: [ModelDownloadProgress]
    private var completion: Result<Void, Error>?

    init() {
        self.continuations = [:]
        self.replay = []
        self.completion = nil
    }

    func stream() -> AsyncThrowingStream<ModelDownloadProgress, Error> {
        AsyncThrowingStream { continuation in
            let id = UUID()

            Task {
                add(continuation, id: id)
            }

            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.removeContinuation(id: id)
                }
            }
        }
    }

    func yield(_ progress: ModelDownloadProgress) {
        replay.append(progress)
        for continuation in continuations.values {
            continuation.yield(progress)
        }
    }

    func finish(throwing error: Error? = nil) {
        if let error {
            completion = .failure(error)
            for continuation in continuations.values {
                continuation.finish(throwing: error)
            }
        } else {
            completion = .success(())
            for continuation in continuations.values {
                continuation.finish()
            }
        }
        continuations.removeAll()
    }

    private func add(
        _ continuation: AsyncThrowingStream<ModelDownloadProgress, Error>.Continuation,
        id: UUID
    ) {
        for progress in replay {
            continuation.yield(progress)
        }

        switch completion {
        case .success:
            continuation.finish()
        case .failure(let error):
            continuation.finish(throwing: error)
        case nil:
            continuations[id] = continuation
        }
    }

    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }
}
