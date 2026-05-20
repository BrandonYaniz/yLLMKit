#if canImport(XCTest)
import Foundation
import MLXLMCommon
import XCTest
import yLLMKit
@testable import yLLMKitMLX

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

    func testMLXProgressUsesFractionCompleted() {
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 42

        let mapped = MLXDownloadProgressMapper.downloadingProgress(
            modelID: "phi-2",
            progress: progress,
            message: nil
        )

        XCTAssertEqual(try XCTUnwrap(mapped.fractionCompleted), 0.42, accuracy: 0.0001)
    }

    func testMLXProgressDoesNotTreatUnitCountsAsBytes() {
        let progress = Progress(totalUnitCount: 10)
        progress.completedUnitCount = 0

        let mapped = MLXDownloadProgressMapper.downloadingProgress(
            modelID: "phi-2",
            progress: progress,
            message: nil
        )

        XCTAssertEqual(mapped.fractionCompleted, 0.0)
        XCTAssertNil(mapped.completedBytes)
        XCTAssertNil(mapped.totalBytes)
    }

    func testDownloadCompletionReportsCompleteFraction() {
        let progress = ModelDownloadProgress(
            modelID: "phi-2",
            phase: .complete,
            fractionCompleted: 1.0
        )

        XCTAssertEqual(progress.fractionCompleted, 1.0)
    }

    func testMLXPromptBuilderUsesSingleUserPrompt() throws {
        let request = try MLXPromptBuilder.promptRequest(
            from: [
                LLMMessage(role: .system, content: "Be concise."),
                LLMMessage(role: .user, content: "Say hello.")
            ]
        )

        XCTAssertEqual(request.instructions, "Be concise.")
        XCTAssertTrue(request.history.isEmpty)
        XCTAssertEqual(request.prompt.role, .user)
        XCTAssertEqual(request.prompt.content, "Say hello.")
    }

    func testMLXPromptBuilderKeepsStructuredConversationHistory() throws {
        let request = try MLXPromptBuilder.promptRequest(
            from: [
                LLMMessage(role: .system, content: "Be concise."),
                LLMMessage(role: .user, content: "Hello."),
                LLMMessage(role: .assistant, content: "Hi."),
                LLMMessage(role: .user, content: "What next?")
            ]
        )

        XCTAssertEqual(request.instructions, "Be concise.")
        XCTAssertEqual(request.history.map(\.role), [.user, .assistant])
        XCTAssertEqual(request.history.map(\.content), ["Hello.", "Hi."])
        XCTAssertEqual(request.prompt.role, .user)
        XCTAssertEqual(request.prompt.content, "What next?")
    }

    func testMLXPromptBuilderRejectsSystemOnlyMessages() {
        XCTAssertThrowsError(
            try MLXPromptBuilder.promptRequest(
                from: [LLMMessage(role: .system, content: "Be concise.")]
            )
        )
    }

    func testGenerationStateRejectsOverlappingRuns() {
        let state = GenerationState()

        let first = state.beginGeneration()
        let second = state.beginGeneration()

        XCTAssertNotNil(first)
        XCTAssertNil(second)
    }

    func testGenerationStateAllowsRunAfterCancellationFinishes() throws {
        let state = GenerationState()
        let first = try XCTUnwrap(state.beginGeneration())

        state.cancelActiveGeneration()
        XCTAssertTrue(state.isCancelled(first))
        state.finishGeneration(first)

        let second = state.beginGeneration()
        XCTAssertNotNil(second)
    }

    func testLiveMLXSmokeWhenEnabled() async throws {
        guard ProcessInfo.processInfo.environment["YLLMKIT_RUN_MLX_SMOKE"] == "1" else {
            throw XCTSkip("Set YLLMKIT_RUN_MLX_SMOKE=1 to run a live MLX download/inference smoke test.")
        }

        let modelID = ProcessInfo.processInfo.environment["YLLMKIT_MLX_SMOKE_MODEL"] ?? "phi-2"
        let registry = try ModelRegistry(models: SupportedModelCatalog.all)
        let storeRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("yLLMKitMLXSmoke")
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: storeRoot) }

        let runtime = try LLMRuntime(
            modelRegistry: registry,
            modelStore: try FileModelStore(rootDirectory: storeRoot),
            backends: [MLXBackend()]
        )

        let stream = try await runtime.downloadAndInstallModel(id: modelID)
        for try await _ in stream {}

        try await runtime.loadModel(id: modelID)
        let session = try await runtime.createSession(
            modelID: modelID,
            configuration: SessionConfiguration(systemPrompt: "Answer briefly.")
        )

        var output = ""
        for try await token in session.streamResponse(
            to: [LLMMessage(role: .user, content: "Reply with the word ready.")],
            settings: GenerationSettings(
                temperature: 0.0,
                topP: 1.0,
                maxTokens: 8
            )
        ) {
            output += token.text
        }

        XCTAssertFalse(output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
#endif
