import Foundation

public struct MockLLMBackend: LLMBackend {
    public let id: String
    public let name: String

    private let models: [ModelDescriptor]
    private let responseText: String
    private let downloadRoot: URL?

    public init(
        id: String = "mock",
        name: String = "Mock",
        models: [ModelDescriptor],
        responseText: String = "mock response",
        downloadRoot: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.models = models
        self.responseText = responseText
        self.downloadRoot = downloadRoot
    }

    public func availableModels() async throws -> [ModelDescriptor] {
        models
    }

    public func localModels() async throws -> [LocalModel] {
        []
    }

    public func downloadModel(_ request: ModelDownloadRequest) async -> AsyncThrowingStream<ModelDownloadProgress, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(
                ModelDownloadProgress(
                    modelID: request.model.id,
                    phase: .queued
                )
            )
            continuation.yield(
                ModelDownloadProgress(
                    modelID: request.model.id,
                    phase: .downloading,
                    completedBytes: 1,
                    totalBytes: 2
                )
            )

            do {
                let localModel = try installMockModelIfNeeded(request.model)
                continuation.yield(
                    ModelDownloadProgress(
                        modelID: request.model.id,
                        phase: .complete,
                        completedBytes: 2,
                        totalBytes: 2,
                        localModel: localModel
                    )
                )
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    public func loadModel(_ model: ModelDescriptor, from localModel: LocalModel?) async throws -> LoadedModel {
        LoadedModel(model: model, localModel: localModel)
    }

    public func unloadModel(_ modelID: String) async throws {}

    public func createSession(
        model: LoadedModel,
        configuration: SessionConfiguration
    ) async throws -> any LLMSession {
        MockLLMSession(model: model.model, responseText: responseText)
    }

    private func installMockModelIfNeeded(_ model: ModelDescriptor) throws -> LocalModel? {
        guard let downloadRoot else {
            return nil
        }

        let modelDirectory = downloadRoot.appendingPathComponent(model.id)
        try FileManager.default.createDirectory(
            at: modelDirectory,
            withIntermediateDirectories: true
        )
        try Data("mock model".utf8).write(
            to: modelDirectory.appendingPathComponent("weights.bin")
        )

        return LocalModel(
            id: "local-\(model.id)",
            modelID: model.id,
            backendID: model.backendID,
            path: modelDirectory.path,
            installedAt: Date()
        )
    }
}

public struct MockLLMSession: LLMSession {
    public let id: UUID
    public let model: ModelDescriptor

    private let responseText: String

    public init(
        id: UUID = UUID(),
        model: ModelDescriptor,
        responseText: String = "mock response"
    ) {
        self.id = id
        self.model = model
        self.responseText = responseText
    }

    public func respond(
        to messages: [LLMMessage],
        settings: GenerationSettings
    ) async throws -> LLMResponse {
        let text = responseText.truncated(atFirst: settings.stopSequences)
        let tokens = text.split(separator: " ", omittingEmptySubsequences: false)
            .enumerated()
            .map { index, chunk in
                LLMToken(
                    text: index == 0 ? String(chunk) : " \(chunk)",
                    index: index
                )
            }

        return LLMResponse(
            content: text,
            finishReason: .stop,
            tokens: tokens
        )
    }

    public func streamResponse(
        to messages: [LLMMessage],
        settings: GenerationSettings
    ) -> AsyncThrowingStream<LLMToken, Error> {
        AsyncThrowingStream { continuation in
            for token in responseTokens(settings: settings) {
                continuation.yield(token)
            }
            continuation.finish()
        }
    }

    public func cancel() {}

    private func responseTokens(settings: GenerationSettings) -> [LLMToken] {
        responseText.truncated(atFirst: settings.stopSequences)
            .split(separator: " ", omittingEmptySubsequences: false)
            .enumerated()
            .map { index, chunk in
                LLMToken(
                    text: index == 0 ? String(chunk) : " \(chunk)",
                    index: index
                )
            }
    }
}

private extension String {
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
