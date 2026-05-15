#if canImport(XCTest)
import MLXLMCommon
import XCTest
import yLLMKit
import yLLMKitMLX

final class yLLMKitMLXTests: XCTestCase {
    func testMLXConfigurationUsesRepositoryAndRevision() {
        let model = ModelDescriptor(
            id: "phi-3.5-mini",
            displayName: "Phi-3.5 Mini",
            backendID: "mlx",
            provider: "huggingface",
            repository: "mlx-community/Phi-3.5-mini-instruct-4bit",
            revision: "main",
            capabilities: .chatOnly(contextWindow: 131072),
            defaultSettings: GenerationSettings(
                temperature: 0.3,
                topP: 0.9,
                stopSequences: ["<|end|>"]
            )
        )

        let configuration = MLXModelConfigurationFactory.configuration(for: model)

        switch configuration.id {
        case .id(let repository, let revision):
            XCTAssertEqual(repository, "mlx-community/Phi-3.5-mini-instruct-4bit")
            XCTAssertEqual(revision, "main")
        case .directory:
            XCTFail("Expected Hugging Face model id.")
        }
        XCTAssertEqual(configuration.extraEOSTokens, ["<|end|>"])
    }

    func testMLXConfigurationCanUseLocalModelPath() {
        let model = SupportedModelCatalog.phi2
        let localModel = LocalModel(
            id: "local-phi-2",
            modelID: model.id,
            backendID: model.backendID,
            path: "/tmp/phi-2",
            installedAt: Date(timeIntervalSince1970: 1)
        )

        let configuration = MLXModelConfigurationFactory.configuration(
            for: model,
            localModel: localModel
        )

        switch configuration.id {
        case .id:
            XCTFail("Expected local model directory.")
        case .directory(let url):
            XCTAssertEqual(url.path, "/tmp/phi-2")
        }
    }

    func testMLXBackendReportsSupportedModels() async throws {
        let backend = MLXBackend()

        let modelIDs = try await backend.availableModels().map(\.id)

        XCTAssertTrue(modelIDs.contains("fast-local-assistant"))
        XCTAssertTrue(modelIDs.contains("phi-2"))
        XCTAssertTrue(modelIDs.contains("phi-3.5-mini"))
        XCTAssertTrue(modelIDs.contains("phi-3.5-moe"))
    }
}
#endif
