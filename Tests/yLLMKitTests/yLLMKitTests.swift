#if canImport(XCTest)
import Foundation
import XCTest
@testable import yLLMKit

final class yLLMKitTests: XCTestCase {
    private func sampleManifestData() throws -> Data {
        let manifestURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("examples/sample-model-manifest.json")
        return try Data(contentsOf: manifestURL)
    }

    func testMessageInitialization() {
        let message = LLMMessage(
            role: .user,
            content: "Summarize this context.",
            metadata: ["source": "test"]
        )

        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Summarize this context.")
        XCTAssertEqual(message.metadata["source"], "test")
    }

    func testGenerationSettingsPresets() {
        XCTAssertEqual(GenerationSettings.balanced.temperature, 0.7)
        XCTAssertEqual(GenerationSettings.balanced.topP, 0.9)
        XCTAssertEqual(GenerationSettings.precise.temperature, 0.2)
        XCTAssertEqual(GenerationSettings.precise.topP, 0.8)
        XCTAssertNil(GenerationSettings.balanced.maxOutputTokens)
    }

    func testGenerationSettingsAllowProviderDefaults() throws {
        let settings = GenerationSettings(maxOutputTokens: 128)

        XCTAssertNil(settings.temperature)
        XCTAssertNil(settings.topP)
        XCTAssertEqual(settings.maxOutputTokens, 128)
        XCTAssertTrue(settings.stopSequences.isEmpty)

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(GenerationSettings.self, from: data)

        XCTAssertEqual(decoded, settings)
    }

    func testV1MessageRolesAreTextChatOnly() {
        XCTAssertEqual(LLMRole.system.rawValue, "system")
        XCTAssertEqual(LLMRole.user.rawValue, "user")
        XCTAssertEqual(LLMRole.assistant.rawValue, "assistant")
        XCTAssertNil(LLMRole(rawValue: "tool"))
    }

    func testProviderScopedModelIDEqualityAndDescription() {
        let mlxPhi = LLMModelID(
            providerID: LLMProviderID(rawValue: "mlx"),
            modelName: "phi-3.5-mini"
        )
        let openAIPhi = LLMModelID(
            providerID: LLMProviderID(rawValue: "openai"),
            modelName: "phi-3.5-mini"
        )

        XCTAssertNotEqual(mlxPhi, openAIPhi)
        XCTAssertEqual(mlxPhi.description, "mlx:phi-3.5-mini")
    }

    func testProviderTypesCodableRoundTrip() throws {
        let modelID = LLMModelID(
            providerID: LLMProviderID(rawValue: "mock"),
            modelName: "chat"
        )
        let request = LLMChatRequest(
            modelID: modelID,
            messages: [
                LLMMessage(role: .system, content: "Be concise."),
                LLMMessage(role: .user, content: "Hello")
            ],
            settings: GenerationSettings(
                temperature: 0.1,
                topP: 1.0,
                maxOutputTokens: 32
            ),
            providerOptions: LLMProviderOptions(
                values: [
                    "seed": .number(42),
                    "label": .string("test"),
                    "enabled": .bool(true),
                    "tags": .array([.string("a"), .string("b")]),
                    "extra": .object(["nested": .null])
                ]
            )
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(LLMChatRequest.self, from: data)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertEqual(decoded, request)
        XCTAssertEqual(decoded.settings.maxTokens, 32)
        XCTAssertEqual(decoded.providerOptions.values["label"], .string("test"))
        XCTAssertTrue(json.contains("\"providerID\":\"mock\""))
    }

    func testModelDescriptorCarriesProviderMetadata() throws {
        let descriptor = providerModelDescriptor(
            providerID: "mlx",
            modelName: "phi-3.5-mini",
            metadata: [
                "repository": .string("mlx-community/Phi-3.5-mini-instruct-4bit"),
                "recommendedRAMGB": .number(8)
            ]
        )

        let data = try JSONEncoder().encode(descriptor)
        let decoded = try JSONDecoder().decode(LLMModelDescriptor.self, from: data)

        XCTAssertEqual(decoded, descriptor)
        XCTAssertEqual(
            decoded.providerMetadata["repository"],
            .string("mlx-community/Phi-3.5-mini-instruct-4bit")
        )
    }

    func testMockProviderStreamsCompletionWithUsage() async throws {
        let model = providerModelDescriptor(providerID: "mock", modelName: "chat")
        let provider = MockLLMProvider(models: [model], responseText: "mock response")
        let request = LLMChatRequest(
            modelID: model.id,
            messages: [LLMMessage(role: .user, content: "Hello")]
        )

        try await provider.prepareModel(model.id)

        var events: [LLMStreamEvent] = []
        for try await event in provider.streamChat(request: request) {
            events.append(event)
        }

        XCTAssertEqual(events.first, .started(LLMStreamStart(modelID: model.id)))
        XCTAssertEqual(events.dropFirst().first, .textDelta("mock"))
        XCTAssertEqual(events.dropFirst(2).first, .textDelta(" response"))

        guard case .completed(let response) = events.last else {
            return XCTFail("Expected completed event.")
        }

        XCTAssertEqual(response.modelID, model.id)
        XCTAssertEqual(response.message.role, .assistant)
        XCTAssertEqual(response.message.content, "mock response")
        XCTAssertEqual(response.usage?.outputTokens, 2)
        XCTAssertEqual(response.finishReason, .stop)
    }

    func testMockProviderFailsMissingModel() async throws {
        let model = providerModelDescriptor(providerID: "mock", modelName: "chat")
        let missingModelID = LLMModelID(
            providerID: LLMProviderID(rawValue: "mock"),
            modelName: "missing"
        )
        let provider = MockLLMProvider(models: [model])

        do {
            try await provider.prepareModel(missingModelID)
            XCTFail("Expected missing model preparation to throw.")
        } catch LLMProviderError.modelNotFound(missingModelID) {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCodableRoundTrip() throws {
        let response = LLMResponse(
            content: "Done",
            finishReason: .stop,
            tokens: [
                LLMToken(text: "Done", index: 0)
            ],
            metadata: ["model": "test"]
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(LLMResponse.self, from: data)

        XCTAssertEqual(decoded, response)
    }

    func testSampleModelManifestDecodes() throws {
        let data = try sampleManifestData()
        let manifest = try JSONDecoder().decode(ModelManifest.self, from: data)

        XCTAssertEqual(manifest.models.count, 1)
        let model = try XCTUnwrap(manifest.models.first)
        XCTAssertEqual(model.id, "fast-local-assistant")
        XCTAssertEqual(model.displayName, "Fast Local Assistant")
        XCTAssertEqual(model.backendID, "mlx")
        XCTAssertEqual(model.provider, "huggingface")
        XCTAssertEqual(model.repository, "mlx-community/gemma-3-1b-it-qat-4bit")
        XCTAssertEqual(model.recommendedRAMGB, 8)
        XCTAssertTrue(model.capabilities.supportsChat)
        XCTAssertFalse(model.capabilities.supportsVision)
        XCTAssertEqual(model.capabilities.contextWindow, 32768)
        XCTAssertEqual(model.capabilities.preferredMaxOutputTokens, 4096)
        XCTAssertEqual(model.defaultSettings.maxTokens, 2048)
    }

    func testModelManifestSupportsModelArrays() throws {
        let model = ModelDescriptor(
            id: "test-model",
            displayName: "Test Model",
            backendID: "mock",
            provider: "local",
            repository: "models/test",
            capabilities: ModelCapabilities(
                supportsChat: true,
                supportsCompletion: false,
                supportsVision: false,
                supportsEmbeddings: false,
                supportsToolCalling: false,
                supportsJSONMode: false,
                contextWindow: 4096
            ),
            defaultSettings: .balanced
        )
        let manifest = ModelManifest(models: [model])

        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(ModelManifest.self, from: data)

        XCTAssertEqual(decoded, manifest)
    }

    func testSupportedModelCatalogIncludesPhiModels() async throws {
        let registry = try ModelRegistry(models: SupportedModelCatalog.all)

        let phiModels = await registry.models(forBackend: "mlx")
            .filter { $0.id.hasPrefix("phi-") }
        let phiMiniRepository = try await registry.model(id: "phi-3.5-mini").repository
        let phiMoEStopSequences = try await registry.model(id: "phi-3.5-moe").defaultSettings.stopSequences

        XCTAssertEqual(
            phiModels.map(\.id),
            [
                "phi-2",
                "phi-3.5-mini",
                "phi-3.5-moe",
            ]
        )
        XCTAssertEqual(phiMiniRepository, "mlx-community/Phi-3.5-mini-instruct-4bit")
        XCTAssertEqual(phiMoEStopSequences, ["<|end|>"])
    }

    func testModelRegistryLoadsManifestData() async throws {
        let registry = try ModelRegistry(manifestData: sampleManifestData())

        let supportedModels = await registry.supportedModels()
        let model = try await registry.model(id: "fast-local-assistant")

        XCTAssertEqual(supportedModels, [model])
        XCTAssertEqual(model.backendID, "mlx")
    }

    func testModelRegistryFiltersByBackend() async throws {
        let mlxModel = ModelDescriptor(
            id: "mlx-model",
            displayName: "MLX Model",
            backendID: "mlx",
            provider: "local",
            repository: "models/mlx",
            capabilities: .chatOnly(contextWindow: 4096),
            defaultSettings: .balanced
        )
        let mockModel = ModelDescriptor(
            id: "mock-model",
            displayName: "Mock Model",
            backendID: "mock",
            provider: "local",
            repository: "models/mock",
            capabilities: .chatOnly(contextWindow: 4096),
            defaultSettings: .balanced
        )
        let registry = try ModelRegistry(models: [mockModel, mlxModel])

        let mlxModels = await registry.models(forBackend: "mlx")

        XCTAssertEqual(mlxModels, [mlxModel])
    }

    func testModelRegistryThrowsForMissingModel() async throws {
        let registry = try ModelRegistry(models: [])

        do {
            _ = try await registry.model(id: "missing")
            XCTFail("Expected missing model lookup to throw.")
        } catch LLMError.modelNotFound("missing") {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testModelRegistryRejectsDuplicateIDs() {
        let model = ModelDescriptor(
            id: "duplicate",
            displayName: "Duplicate",
            backendID: "mock",
            provider: "local",
            repository: "models/duplicate",
            capabilities: .chatOnly(contextWindow: 4096),
            defaultSettings: .balanced
        )

        XCTAssertThrowsError(try ModelRegistry(models: [model, model]))
    }

    func testFileModelStoreRegistersAndFindsLocalModel() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let modelDirectory = root.appendingPathComponent("fast-local-assistant")
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data("model".utf8).write(to: modelDirectory.appendingPathComponent("weights.bin"))

        let store = try FileModelStore(rootDirectory: root)
        let localModel = LocalModel(
            id: "local-fast-local-assistant",
            modelID: "fast-local-assistant",
            backendID: "mlx",
            path: modelDirectory.path,
            installedAt: Date(timeIntervalSince1970: 1)
        )

        try await store.register(localModel)

        let storedModel = await store.localModel(for: "fast-local-assistant")
        let isInstalled = await store.isModelInstalled("fast-local-assistant")
        XCTAssertEqual(storedModel?.modelID, "fast-local-assistant")
        XCTAssertEqual(storedModel?.sizeBytes, 5)
        XCTAssertTrue(isInstalled)
    }

    func testFileModelStorePersistsIndex() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let modelDirectory = root.appendingPathComponent("mock-model")
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        let firstStore = try FileModelStore(rootDirectory: root)
        try await firstStore.register(
            LocalModel(
                id: "local-mock-model",
                modelID: "mock-model",
                backendID: "mock",
                path: modelDirectory.path,
                installedAt: Date(timeIntervalSince1970: 2),
                sizeBytes: 10
            )
        )

        let secondStore = try FileModelStore(rootDirectory: root)
        let localModels = await secondStore.localModels()

        XCTAssertEqual(localModels.map(\.modelID), ["mock-model"])
        XCTAssertEqual(localModels.first?.sizeBytes, 10)
    }

    func testFileModelStoreRemovesLocalModel() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let modelDirectory = root.appendingPathComponent("remove-me")
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        let store = try FileModelStore(rootDirectory: root)
        try await store.register(
            LocalModel(
                id: "local-remove-me",
                modelID: "remove-me",
                backendID: "mock",
                path: modelDirectory.path,
                installedAt: Date(timeIntervalSince1970: 3)
            )
        )

        try await store.removeModel(id: "remove-me")

        let removedModel = await store.localModel(for: "remove-me")
        XCTAssertNil(removedModel)
        XCTAssertFalse(FileManager.default.fileExists(atPath: modelDirectory.path))
    }

    func testFileModelStoreDoesNotRemoveExternalPathByDefault() async throws {
        let root = temporaryDirectory()
        let externalRoot = temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: externalRoot)
        }
        let modelDirectory = externalRoot.appendingPathComponent("external-model")
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        let store = try FileModelStore(rootDirectory: root)
        try await store.register(
            LocalModel(
                id: "local-external-model",
                modelID: "external-model",
                backendID: "mock",
                path: modelDirectory.path,
                installedAt: Date(timeIntervalSince1970: 5)
            )
        )

        try await store.removeModel(id: "external-model")

        let removedModel = await store.localModel(for: "external-model")
        XCTAssertNil(removedModel)
        XCTAssertTrue(FileManager.default.fileExists(atPath: modelDirectory.path))
    }

    func testFileModelStoreCanRemoveRegisteredExternalPath() async throws {
        let root = temporaryDirectory()
        let externalRoot = temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: externalRoot)
        }
        let modelDirectory = externalRoot.appendingPathComponent("external-model")
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        let store = try FileModelStore(
            rootDirectory: root,
            removalPolicy: .registeredPaths
        )
        try await store.register(
            LocalModel(
                id: "local-external-model",
                modelID: "external-model",
                backendID: "mock",
                path: modelDirectory.path,
                installedAt: Date(timeIntervalSince1970: 6)
            )
        )

        try await store.removeModel(id: "external-model")

        let removedModel = await store.localModel(for: "external-model")
        XCTAssertNil(removedModel)
        XCTAssertFalse(FileManager.default.fileExists(atPath: modelDirectory.path))
    }

    func testRuntimeLoadsModelAndStreamsTokens() async throws {
        let model = mockModel(id: "chat-model", backendID: "mock")
        let registry = try ModelRegistry(models: [model])
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try FileModelStore(rootDirectory: root)
        try await registerInstalledMockModel(model, in: store, root: root)
        let runtime = try LLMRuntime(
            modelRegistry: registry,
            modelStore: store,
            backends: [MockLLMBackend(models: [model])]
        )

        let loadedModel = try await runtime.loadModel(id: "chat-model")
        let session = try await runtime.createSession(
            modelID: loadedModel.id,
            configuration: SessionConfiguration(systemPrompt: nil)
        )

        var tokens: [LLMToken] = []
        for try await token in session.streamResponse(
            to: [LLMMessage(role: .user, content: "Hello")],
            settings: .balanced
        ) {
            tokens.append(token)
        }

        XCTAssertEqual(loadedModel.model, model)
        XCTAssertEqual(tokens.map(\.text), ["mock", " response"])
    }

    func testRuntimeCoalescesConcurrentModelLoads() async throws {
        let model = mockModel(id: "shared-load-model", backendID: "counting")
        let registry = try ModelRegistry(models: [model])
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try FileModelStore(rootDirectory: root)
        try await registerInstalledMockModel(model, in: store, root: root)
        let backend = CountingBackend(models: [model])
        let runtime = try LLMRuntime(
            modelRegistry: registry,
            modelStore: store,
            backends: [backend]
        )

        let loadedModels = try await withThrowingTaskGroup(of: LoadedModel.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try await runtime.loadModel(id: model.id)
                }
            }

            var values: [LoadedModel] = []
            for try await value in group {
                values.append(value)
            }
            return values
        }

        let loadCount = await backend.loadCount
        XCTAssertEqual(loadedModels.count, 5)
        XCTAssertEqual(Set(loadedModels.map(\.id)), [model.id])
        XCTAssertTrue(loadedModels.allSatisfy { $0.loadTimeSeconds != nil })
        XCTAssertEqual(loadCount, 1)
    }

    func testMockSessionHonorsStopSequences() async throws {
        let session = MockLLMSession(
            model: mockModel(id: "stop-model", backendID: "mock"),
            responseText: "first STOP second"
        )

        let response = try await session.respond(
            to: [LLMMessage(role: .user, content: "Hello")],
            settings: GenerationSettings(
                temperature: 0.0,
                topP: 1.0,
                stopSequences: ["STOP"]
            )
        )

        XCTAssertEqual(response.content, "first ")
        XCTAssertEqual(response.tokens.map(\.text), ["first", " "])
    }

    func testMockStreamHonorsStopSequences() async throws {
        let session = MockLLMSession(
            model: mockModel(id: "stop-model", backendID: "mock"),
            responseText: "first STOP second"
        )

        var output = ""
        for try await token in session.streamResponse(
            to: [LLMMessage(role: .user, content: "Hello")],
            settings: GenerationSettings(
                temperature: 0.0,
                topP: 1.0,
                stopSequences: ["STOP"]
            )
        ) {
            output += token.text
        }

        XCTAssertEqual(output, "first ")
    }

    func testRuntimeRejectsUninstalledModelLoad() async throws {
        let model = mockModel(id: "chat-model", backendID: "mock")
        let registry = try ModelRegistry(models: [model])
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try FileModelStore(rootDirectory: root)
        let runtime = try LLMRuntime(
            modelRegistry: registry,
            modelStore: store,
            backends: [MockLLMBackend(models: [model])]
        )

        do {
            _ = try await runtime.loadModel(id: "chat-model")
            XCTFail("Expected uninstalled model to throw.")
        } catch LLMError.modelNotInstalled("chat-model") {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRuntimeRejectsMissingBackend() async throws {
        let model = mockModel(id: "chat-model", backendID: "missing")
        let registry = try ModelRegistry(models: [model])
        let store = try FileModelStore(rootDirectory: temporaryDirectory())
        let runtime = try LLMRuntime(
            modelRegistry: registry,
            modelStore: store,
            backends: []
        )

        do {
            _ = try await runtime.loadModel(id: "chat-model")
            XCTFail("Expected missing backend to throw.")
        } catch LLMError.backendUnavailable("missing") {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRuntimeRemovesInstalledModel() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = mockModel(id: "removable-model", backendID: "mock")
        let registry = try ModelRegistry(models: [model])
        let store = try FileModelStore(rootDirectory: root)
        try await registerInstalledMockModel(model, in: store, root: root)
        let runtime = try LLMRuntime(
            modelRegistry: registry,
            modelStore: store,
            backends: [MockLLMBackend(models: [model])]
        )

        try await runtime.loadModel(id: model.id)
        try await runtime.removeModel(id: model.id)

        let isInstalled = await store.isModelInstalled(model.id)
        XCTAssertFalse(isInstalled)

        do {
            _ = try await runtime.loadedModel(id: model.id)
            XCTFail("Expected removed model to be unloaded.")
        } catch LLMError.modelNotLoaded(let modelID) where modelID == model.id {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRuntimeRequiresLoadedModelBeforeSession() async throws {
        let model = mockModel(id: "chat-model", backendID: "mock")
        let registry = try ModelRegistry(models: [model])
        let store = try FileModelStore(rootDirectory: temporaryDirectory())
        let runtime = try LLMRuntime(
            modelRegistry: registry,
            modelStore: store,
            backends: [MockLLMBackend(models: [model])]
        )

        do {
            _ = try await runtime.createSession(
                modelID: "chat-model",
                configuration: SessionConfiguration(systemPrompt: nil)
            )
            XCTFail("Expected unloaded model to throw.")
        } catch LLMError.modelNotLoaded("chat-model") {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRuntimeDownloadAndInstallRegistersLocalModel() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = mockModel(id: "downloadable-model", backendID: "mock")
        let registry = try ModelRegistry(models: [model])
        let store = try FileModelStore(rootDirectory: root)
        let runtime = try LLMRuntime(
            modelRegistry: registry,
            modelStore: store,
            backends: [
                MockLLMBackend(
                    models: [model],
                    downloadRoot: root.appendingPathComponent("downloads")
                )
            ]
        )

        let stream = try await runtime.downloadAndInstallModel(id: "downloadable-model")
        var phases: [ModelDownloadProgress.Phase] = []
        for try await progress in stream {
            phases.append(progress.phase)
        }

        let localModel = await store.localModel(for: "downloadable-model")
        let isInstalled = await store.isModelInstalled("downloadable-model")
        XCTAssertEqual(phases, [.queued, .downloading, .complete])
        XCTAssertEqual(localModel?.modelID, "downloadable-model")
        XCTAssertTrue(isInstalled)
    }

    func testRuntimeCoalescesConcurrentDownloads() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = mockModel(id: "shared-download-model", backendID: "counting")
        let registry = try ModelRegistry(models: [model])
        let store = try FileModelStore(rootDirectory: root)
        let backend = CountingBackend(
            models: [model],
            downloadRoot: root.appendingPathComponent("downloads")
        )
        let runtime = try LLMRuntime(
            modelRegistry: registry,
            modelStore: store,
            backends: [backend]
        )

        let phaseSets = try await withThrowingTaskGroup(of: [ModelDownloadProgress.Phase].self) { group in
            for _ in 0..<4 {
                group.addTask {
                    let stream = try await runtime.downloadAndInstallModel(id: model.id)
                    var phases: [ModelDownloadProgress.Phase] = []
                    for try await progress in stream {
                        phases.append(progress.phase)
                    }
                    return phases
                }
            }

            var values: [[ModelDownloadProgress.Phase]] = []
            for try await value in group {
                values.append(value)
            }
            return values
        }

        let downloadCount = await backend.downloadCount
        let isInstalled = await store.isModelInstalled(model.id)
        XCTAssertEqual(phaseSets.count, 4)
        XCTAssertTrue(phaseSets.allSatisfy { $0 == [.queued, .downloading, .complete] })
        XCTAssertEqual(downloadCount, 1)
        XCTAssertTrue(isInstalled)
    }

    func testSessionDefaultResponseAggregatesStreamedTokens() async throws {
        let session = StreamOnlySession(model: mockModel(id: "stream-model", backendID: "mock"))

        let response = try await session.respond(
            to: [LLMMessage(role: .user, content: "Hello")],
            settings: .balanced
        )

        XCTAssertEqual(response.content, "streamed response")
        XCTAssertEqual(response.finishReason, .stop)
        XCTAssertEqual(response.tokens.map(\.text), ["streamed", " response"])
        XCTAssertEqual(response.metrics?.modelID, "stream-model")
        XCTAssertEqual(response.metrics?.outputTokenCount, 2)
        XCTAssertEqual(response.metrics?.wasWarm, true)
        XCTAssertNotNil(response.metrics?.firstTokenLatencySeconds)
        XCTAssertNotNil(response.metrics?.totalGenerationSeconds)
        XCTAssertNotNil(response.metrics?.tokensPerSecond)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("yLLMKitTests")
            .appendingPathComponent(UUID().uuidString)
    }

    private func mockModel(id: String, backendID: String) -> ModelDescriptor {
        ModelDescriptor(
            id: id,
            displayName: "Chat Model",
            backendID: backendID,
            provider: "local",
            repository: "models/\(id)",
            capabilities: .chatOnly(contextWindow: 4096),
            defaultSettings: .balanced
        )
    }

    private func providerModelDescriptor(
        providerID: String,
        modelName: String,
        metadata: [String: JSONValue] = [:]
    ) -> LLMModelDescriptor {
        LLMModelDescriptor(
            id: LLMModelID(
                providerID: LLMProviderID(rawValue: providerID),
                modelName: modelName
            ),
            displayName: "Chat Model",
            capabilities: LLMModelCapabilities(
                supportsStreaming: true,
                supportsLocalPreparation: providerID == "mlx",
                contextWindow: 4096,
                maxOutputTokens: 1024
            ),
            defaultSettings: .balanced,
            providerMetadata: metadata
        )
    }

    private func registerInstalledMockModel(
        _ model: ModelDescriptor,
        in store: FileModelStore,
        root: URL
    ) async throws {
        let modelDirectory = root.appendingPathComponent(model.id)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data("mock model".utf8).write(to: modelDirectory.appendingPathComponent("weights.bin"))
        try await store.register(
            LocalModel(
                id: "local-\(model.id)",
                modelID: model.id,
                backendID: model.backendID,
                path: modelDirectory.path,
                installedAt: Date(timeIntervalSince1970: 4)
            )
        )
    }
}

private struct StreamOnlySession: LLMSession {
    let id = UUID()
    let model: ModelDescriptor

    func streamResponse(
        to messages: [LLMMessage],
        settings: GenerationSettings
    ) -> AsyncThrowingStream<LLMToken, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(LLMToken(text: "streamed", index: 0))
            continuation.yield(LLMToken(text: " response", index: 1))
            continuation.finish()
        }
    }

    func cancel() {}
}

private actor CountingBackend: LLMBackend {
    let id = "counting"
    let name = "Counting"

    private let models: [ModelDescriptor]
    private let downloadRoot: URL?
    private(set) var loadCount = 0
    private(set) var downloadCount = 0

    init(models: [ModelDescriptor], downloadRoot: URL? = nil) {
        self.models = models
        self.downloadRoot = downloadRoot
    }

    func availableModels() async throws -> [ModelDescriptor] {
        models
    }

    func localModels() async throws -> [LocalModel] {
        []
    }

    func downloadModel(_ request: ModelDownloadRequest) async -> AsyncThrowingStream<ModelDownloadProgress, Error> {
        downloadCount += 1
        let downloadRoot = downloadRoot

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(
                        ModelDownloadProgress(
                            modelID: request.model.id,
                            phase: .queued
                        )
                    )
                    try await Task.sleep(nanoseconds: 30_000_000)
                    continuation.yield(
                        ModelDownloadProgress(
                            modelID: request.model.id,
                            phase: .downloading,
                            fractionCompleted: 0.5
                        )
                    )
                    let localModel = try Self.installMockModel(
                        request.model,
                        downloadRoot: downloadRoot
                    )
                    continuation.yield(
                        ModelDownloadProgress(
                            modelID: request.model.id,
                            phase: .complete,
                            fractionCompleted: 1.0,
                            localModel: localModel
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

    func loadModel(_ model: ModelDescriptor, from localModel: LocalModel?) async throws -> LoadedModel {
        loadCount += 1
        try await Task.sleep(nanoseconds: 30_000_000)
        return LoadedModel(model: model, localModel: localModel)
    }

    func unloadModel(_ modelID: String) async throws {}

    func createSession(
        model: LoadedModel,
        configuration: SessionConfiguration
    ) async throws -> any LLMSession {
        MockLLMSession(model: model.model)
    }

    private static func installMockModel(
        _ model: ModelDescriptor,
        downloadRoot: URL?
    ) throws -> LocalModel? {
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
            installedAt: Date(timeIntervalSince1970: 7)
        )
    }
}
#else
import Foundation
@testable import yLLMKit

let coreTypeSmokeCheck: Void = {
    let message = LLMMessage(role: .user, content: "Hello")
    let token = LLMToken(text: "Hello")
    let response = LLMResponse(content: token.text, finishReason: .stop, tokens: [token])
    let settings = GenerationSettings.balanced
    let configuration = SessionConfiguration(systemPrompt: nil)

    _ = try? JSONEncoder().encode(message)
    _ = try? JSONEncoder().encode(response)
    _ = try? JSONEncoder().encode(settings)
    _ = try? JSONEncoder().encode(configuration)
}()
#endif
