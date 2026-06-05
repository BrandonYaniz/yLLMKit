#if canImport(XCTest)
import Foundation
import XCTest
import yLLMKit
import yLLMKitContext

final class ContextSummarizerTests: XCTestCase {
    func testSummarizeChunksBuildsSummaryChunkWithReferences() async throws {
        let sourceID = UUID()
        let spanReference = ContextSourceReference(
            sourceID: sourceID,
            kind: .span,
            targetID: UUID(),
            label: "Design note"
        )
        let chunks = [
            ContextChunk(
                sourceID: sourceID,
                level: 0,
                kind: .raw,
                text: "The local model cache must survive app relaunch.",
                tokenEstimate: 9,
                sourceReferences: [spanReference],
                createdAt: Date(timeIntervalSince1970: 1)
            ),
            ContextChunk(
                sourceID: sourceID,
                level: 1,
                kind: .summary,
                text: "Remote providers are courtesy integrations.",
                tokenEstimate: 5,
                createdAt: Date(timeIntervalSince1970: 2)
            )
        ]
        let provider = RecordingSummaryProvider(responseText: "Local cache survives relaunch; remote providers are courtesy integrations.")
        let summarizer = ProviderContextSummarizer(
            provider: provider,
            tokenEstimator: SummaryWordCountTokenEstimator()
        )

        let summary = try await summarizer.summarizeChunks(
            ContextChunkSummaryRequest(
                sourceID: sourceID,
                modelID: provider.modelID,
                chunks: chunks,
                settings: .precise,
                metadata: ["contentHash": "summary-hash"]
            )
        )

        XCTAssertEqual(summary.sourceID, sourceID)
        XCTAssertEqual(summary.kind, .summary)
        XCTAssertEqual(summary.level, 2)
        XCTAssertEqual(summary.text, "Local cache survives relaunch; remote providers are courtesy integrations.")
        XCTAssertNotNil(summary.tokenEstimate)
        XCTAssertGreaterThan(summary.tokenEstimate ?? 0, 0)
        XCTAssertEqual(summary.contentHash, "summary-hash")
        XCTAssertTrue(summary.sourceReferences.contains(spanReference))
        XCTAssertEqual(summary.sourceReferences.filter { $0.kind == .chunk }.count, 2)

        let capturedRequest = try XCTUnwrap(provider.capturedRequests.first)
        XCTAssertEqual(capturedRequest.modelID, provider.modelID)
        XCTAssertEqual(capturedRequest.settings, .precise)
        XCTAssertTrue(capturedRequest.messages.last?.content.contains("The local model cache must survive app relaunch.") ?? false)
        XCTAssertTrue(capturedRequest.messages.last?.content.contains("Remote providers are courtesy integrations.") ?? false)
    }

    func testSummarizeChunksOmitsStaleChunks() async throws {
        let sourceID = UUID()
        let provider = RecordingSummaryProvider(responseText: "Only fresh context.")
        let summarizer = ProviderContextSummarizer(
            provider: provider,
            tokenEstimator: SummaryWordCountTokenEstimator()
        )

        _ = try await summarizer.summarizeChunks(
            ContextChunkSummaryRequest(
                sourceID: sourceID,
                modelID: provider.modelID,
                chunks: [
                    ContextChunk(
                        sourceID: sourceID,
                        level: 0,
                        kind: .raw,
                        text: "Fresh context.",
                        createdAt: Date(timeIntervalSince1970: 1)
                    ),
                    ContextChunk(
                        sourceID: sourceID,
                        level: 0,
                        kind: .raw,
                        text: "Stale context.",
                        isStale: true,
                        createdAt: Date(timeIntervalSince1970: 2)
                    )
                ]
            )
        )

        let capturedRequest = try XCTUnwrap(provider.capturedRequests.first)
        XCTAssertTrue(capturedRequest.messages.last?.content.contains("Fresh context.") ?? false)
        XCTAssertFalse(capturedRequest.messages.last?.content.contains("Stale context.") ?? true)
    }

    func testSummarizeConversationBuildsSnapshotThroughLatestTurn() async throws {
        let sourceID = UUID()
        let provider = RecordingSummaryProvider(responseText: "User wants beta-ready local-first APIs.")
        let previousReference = ContextSourceReference(
            sourceID: sourceID,
            kind: .snapshot,
            targetID: UUID(),
            label: "Previous"
        )
        let previousSnapshot = ConversationSnapshot(
            sourceID: sourceID,
            summary: "Earlier discussion covered provider interfaces.",
            sourceReferences: [previousReference]
        )
        let turns = [
            ConversationTurn(sourceID: sourceID, turnIndex: 1, role: .assistant, content: "We added local lifecycle APIs."),
            ConversationTurn(sourceID: sourceID, turnIndex: 2, role: .user, content: "Implement summarization now.")
        ]
        let summarizer = ProviderContextSummarizer(
            provider: provider,
            tokenEstimator: SummaryWordCountTokenEstimator()
        )

        let snapshot = try await summarizer.summarizeConversation(
            ConversationSnapshotSummaryRequest(
                sourceID: sourceID,
                modelID: provider.modelID,
                turns: turns,
                previousSnapshot: previousSnapshot,
                metadata: ["contentHash": "snapshot-hash"]
            )
        )

        XCTAssertEqual(snapshot.sourceID, sourceID)
        XCTAssertEqual(snapshot.summary, "User wants beta-ready local-first APIs.")
        XCTAssertEqual(snapshot.tokenEstimate, 5)
        XCTAssertEqual(snapshot.contentHash, "snapshot-hash")
        XCTAssertEqual(snapshot.builtThroughReference?.kind, .turn)
        XCTAssertEqual(snapshot.builtThroughReference?.targetID, turns[1].id)
        XCTAssertTrue(snapshot.sourceReferences.contains(previousReference))
        XCTAssertEqual(snapshot.sourceReferences.filter { $0.kind == .turn }.count, 2)

        let capturedRequest = try XCTUnwrap(provider.capturedRequests.first)
        XCTAssertTrue(capturedRequest.messages.last?.content.contains("Previous summary:") ?? false)
        XCTAssertTrue(capturedRequest.messages.last?.content.contains("Turn 2 user: Implement summarization now.") ?? false)
    }

    func testSummarizerRejectsEmptyInputs() async throws {
        let sourceID = UUID()
        let provider = RecordingSummaryProvider(responseText: "unused")
        let summarizer = ProviderContextSummarizer(provider: provider)

        do {
            _ = try await summarizer.summarizeChunks(
                ContextChunkSummaryRequest(
                    sourceID: sourceID,
                    modelID: provider.modelID,
                    chunks: []
                )
            )
            XCTFail("Expected empty chunk summary input to fail.")
        } catch ContextSummarizationError.emptyInput {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await summarizer.summarizeConversation(
                ConversationSnapshotSummaryRequest(
                    sourceID: sourceID,
                    modelID: provider.modelID,
                    turns: []
                )
            )
            XCTFail("Expected empty conversation summary input to fail.")
        } catch ContextSummarizationError.emptyInput {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private struct SummaryWordCountTokenEstimator: ContextTokenEstimator {
    func estimateTokenCount(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}

private final class RecordingSummaryProvider: LLMProvider, @unchecked Sendable {
    let providerID = LLMProviderID(rawValue: "summary")
    let modelID: LLMModelID

    private let responseText: String
    private let lock = NSLock()
    private var requests: [LLMChatRequest] = []

    var capturedRequests: [LLMChatRequest] {
        lock.withLock { requests }
    }

    init(responseText: String) {
        self.responseText = responseText
        self.modelID = LLMModelID(providerID: providerID, modelName: "summary-model")
    }

    func availableModels() async throws -> [LLMModelDescriptor] {
        [
            LLMModelDescriptor(
                id: modelID,
                displayName: "Summary Model",
                capabilities: LLMModelCapabilities(
                    supportsStreaming: true,
                    supportsLocalPreparation: false
                )
            )
        ]
    }

    func prepareModel(_ modelID: LLMModelID) async throws {
        guard modelID == self.modelID else {
            throw LLMProviderError.modelNotFound(modelID)
        }
    }

    func streamChat(
        request: LLMChatRequest
    ) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        lock.withLock {
            requests.append(request)
        }
        let responseText = responseText

        return AsyncThrowingStream { continuation in
            continuation.yield(.started(LLMStreamStart(modelID: request.modelID)))
            continuation.yield(.textDelta(responseText))
            continuation.yield(
                .completed(
                    LLMChatResponse(
                        modelID: request.modelID,
                        message: LLMMessage(role: .assistant, content: responseText),
                        finishReason: .stop
                    )
                )
            )
            continuation.finish()
        }
    }
}
#endif
