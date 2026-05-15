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

        let storedModel = try await store.localModel(for: "fast-local-assistant")
        XCTAssertEqual(storedModel?.modelID, "fast-local-assistant")
        XCTAssertEqual(storedModel?.sizeBytes, 5)
        XCTAssertTrue(try await store.isModelInstalled("fast-local-assistant"))
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
        let localModels = try await secondStore.localModels()

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

        XCTAssertNil(try await store.localModel(for: "remove-me"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: modelDirectory.path))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("yLLMKitTests")
            .appendingPathComponent(UUID().uuidString)
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
