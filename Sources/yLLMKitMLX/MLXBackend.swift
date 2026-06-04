import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers
import yLLMKit

public actor MLXBackend: LLMBackend {
    public nonisolated let id = "mlx"
    public nonisolated let name = "MLX"

    private let models: [ModelDescriptor]
    private var containersByModelID: [String: ModelContainer]
    private var localModelsByModelID: [String: LocalModel]
    private var loadingContainersByModelID: [String: Task<LoadedMLXContainer, Error>]

    public init(models: [ModelDescriptor] = SupportedModelCatalog.all.filter { $0.backendID == "mlx" }) {
        self.models = models
        self.containersByModelID = [:]
        self.localModelsByModelID = [:]
        self.loadingContainersByModelID = [:]
    }

    public func availableModels() async throws -> [ModelDescriptor] {
        models
    }

    public func localModels() async throws -> [LocalModel] {
        localModelsByModelID.values.sorted { $0.modelID < $1.modelID }
    }

    public func isModelPrepared(_ modelID: String) async throws -> Bool {
        containersByModelID[modelID] != nil || localModelsByModelID[modelID] != nil
    }

    public func downloadModel(_ request: ModelDownloadRequest) async -> AsyncThrowingStream<ModelDownloadProgress, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(
                        ModelDownloadProgress(
                            modelID: request.model.id,
                            phase: .queued
                        )
                    )

                    let downloaded = try await Self.downloadModelFiles(
                        for: request.model,
                        progressHandler: { progress in
                            continuation.yield(
                                MLXDownloadProgressMapper.downloadingProgress(
                                    modelID: request.model.id,
                                    progress: progress,
                                    message: progress.localizedDescription
                                )
                            )
                        }
                    )
                    if let localModel = downloaded.localModel {
                        localModelsByModelID[request.model.id] = localModel
                    }

                    continuation.yield(
                        ModelDownloadProgress(
                            modelID: request.model.id,
                            phase: .complete,
                            fractionCompleted: 1.0,
                            completedBytes: downloaded.completedBytes,
                            totalBytes: downloaded.completedBytes,
                            localModel: downloaded.localModel
                        )
                    )
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

    public func downloadAndWarmModel(_ request: ModelDownloadRequest) async -> AsyncThrowingStream<ModelDownloadProgress, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(
                        ModelDownloadProgress(
                            modelID: request.model.id,
                            phase: .queued
                        )
                    )

                    let loaded = try await Self.loadContainer(
                        for: request.model,
                        localModel: nil
                    ) { progress in
                        continuation.yield(
                            MLXDownloadProgressMapper.downloadingProgress(
                                modelID: request.model.id,
                                progress: progress,
                                message: progress.localizedDescription
                            )
                        )
                    }

                    containersByModelID[request.model.id] = loaded.container
                    if let localModel = loaded.localModel {
                        localModelsByModelID[request.model.id] = localModel
                    }

                    continuation.yield(
                        ModelDownloadProgress(
                            modelID: request.model.id,
                            phase: .complete,
                            fractionCompleted: 1.0,
                            completedBytes: loaded.completedBytes,
                            totalBytes: loaded.completedBytes,
                            localModel: loaded.localModel
                        )
                    )
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

    public func loadModel(_ model: ModelDescriptor, from localModel: LocalModel?) async throws -> LoadedModel {
        if containersByModelID[model.id] == nil {
            let loaded = try await loadedContainer(for: model, localModel: localModel)
            containersByModelID[model.id] = loaded.container
            if let localModel = loaded.localModel {
                localModelsByModelID[model.id] = localModel
            }
        }

        return LoadedModel(
            model: model,
            localModel: localModel ?? localModelsByModelID[model.id]
        )
    }

    public func unloadModel(_ modelID: String) async throws {
        containersByModelID.removeValue(forKey: modelID)
        loadingContainersByModelID[modelID]?.cancel()
        loadingContainersByModelID.removeValue(forKey: modelID)
    }

    public func removeModel(_ modelID: String) async throws {
        try await unloadModel(modelID)
        localModelsByModelID.removeValue(forKey: modelID)
    }

    public func createSession(
        model: LoadedModel,
        configuration: SessionConfiguration
    ) async throws -> any LLMSession {
        guard let container = containersByModelID[model.id] else {
            throw LLMError.modelNotLoaded(model.id)
        }

        return MLXSession(
            model: model.model,
            container: container,
            configuration: configuration
        )
    }

    private func loadedContainer(
        for model: ModelDescriptor,
        localModel: LocalModel?
    ) async throws -> LoadedMLXContainer {
        if let task = loadingContainersByModelID[model.id] {
            return try await task.value
        }

        let task = Task {
            try await Self.loadContainer(for: model, localModel: localModel)
        }
        loadingContainersByModelID[model.id] = task

        do {
            let loaded = try await task.value
            loadingContainersByModelID[model.id] = nil
            return loaded
        } catch {
            loadingContainersByModelID[model.id] = nil
            throw error
        }
    }

    private static func downloadModelFiles(
        for model: ModelDescriptor,
        progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws -> DownloadedMLXModel {
        let resolved = try await resolve(
            configuration: MLXModelConfigurationFactory.configuration(for: model),
            from: #hubDownloader(),
            useLatest: false,
            progressHandler: progressHandler
        )
        let completedBytes = directorySize(at: resolved.modelDirectory) ?? 0
        let localModel = LocalModel(
            id: "local-\(model.id)",
            modelID: model.id,
            backendID: model.backendID,
            path: resolved.modelDirectory.path,
            installedAt: Date(),
            sizeBytes: completedBytes
        )

        return DownloadedMLXModel(
            localModel: localModel,
            completedBytes: completedBytes
        )
    }

    private static func loadContainer(
        for model: ModelDescriptor,
        localModel: LocalModel?,
        progressHandler: @Sendable @escaping (Progress) -> Void = { _ in }
    ) async throws -> LoadedMLXContainer {
        if let localModel {
            let container = try await loadModelContainer(
                from: URL(fileURLWithPath: localModel.path),
                using: #huggingFaceTokenizerLoader()
            )
            return LoadedMLXContainer(
                container: container,
                localModel: localModel,
                completedBytes: localModel.sizeBytes ?? 0
            )
        }

        let recorder = DownloadRecorder()
        let downloader = RecordingDownloader(
            upstream: #hubDownloader(),
            recorder: recorder
        )
        let container = try await loadModelContainer(
            from: downloader,
            using: #huggingFaceTokenizerLoader(),
            configuration: MLXModelConfigurationFactory.configuration(for: model),
            progressHandler: progressHandler
        )
        let localURL = await recorder.lastDownloadedURL()
        let completedBytes = localURL.flatMap { directorySize(at: $0) } ?? 0
        let localModel = localURL.map { url in
            LocalModel(
                id: "local-\(model.id)",
                modelID: model.id,
                backendID: model.backendID,
                path: url.path,
                installedAt: Date(),
                sizeBytes: completedBytes
            )
        }

        return LoadedMLXContainer(
            container: container,
            localModel: localModel,
            completedBytes: completedBytes
        )
    }

    private static func directorySize(at url: URL) -> Int64? {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else {
            return nil
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true
            else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}

private struct LoadedMLXContainer: Sendable {
    var container: ModelContainer
    var localModel: LocalModel?
    var completedBytes: Int64
}

private struct DownloadedMLXModel: Sendable {
    var localModel: LocalModel?
    var completedBytes: Int64
}

enum MLXDownloadProgressMapper {
    static func downloadingProgress(
        modelID: String,
        progress: Progress,
        message: String?
    ) -> ModelDownloadProgress {
        ModelDownloadProgress(
            modelID: modelID,
            phase: .downloading,
            fractionCompleted: clampedFraction(progress.fractionCompleted),
            message: message
        )
    }

    private static func clampedFraction(_ value: Double) -> Double? {
        guard value.isFinite else {
            return nil
        }
        return min(1.0, max(0.0, value))
    }
}

private actor DownloadRecorder {
    private var url: URL?

    func record(_ url: URL) {
        self.url = url
    }

    func lastDownloadedURL() -> URL? {
        url
    }
}

private struct RecordingDownloader: Downloader {
    var upstream: any Downloader
    var recorder: DownloadRecorder

    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        let url = try await upstream.download(
            id: id,
            revision: revision,
            matching: patterns,
            useLatest: useLatest,
            progressHandler: progressHandler
        )
        await recorder.record(url)
        return url
    }
}
