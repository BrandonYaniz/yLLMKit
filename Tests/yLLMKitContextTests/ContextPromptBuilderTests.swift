#if canImport(XCTest)
import Foundation
import XCTest
import yLLMKit
import yLLMKitContext

final class ContextPromptBuilderTests: XCTestCase {
    func testBuilderProducesPromptReadyMessagesInDeterministicOrder() {
        let sourceID = UUID()
        let spanReference = ContextSourceReference(
            sourceID: sourceID,
            kind: .span,
            targetID: UUID(),
            label: "Manual"
        )
        let turn = ConversationTurn(
            sourceID: sourceID,
            turnIndex: 0,
            role: .assistant,
            content: "Earlier answer",
            tokenEstimate: 2
        )
        let request = ContextPromptBuildRequest(
            systemPrompt: "Answer concisely",
            snapshot: ConversationSnapshot(
                sourceID: sourceID,
                summary: "Previous topic was setup.",
                tokenEstimate: 4,
                sourceReferences: [spanReference]
            ),
            retrievedChunks: [
                ContextChunk(
                    sourceID: sourceID,
                    level: 0,
                    kind: .raw,
                    text: "Install steps",
                    tokenEstimate: 2,
                    sourceReferences: [spanReference]
                )
            ],
            recentTurns: [turn],
            finalUserMessage: "What next?",
            budget: ContextBudget(maximumInputTokens: 30, reservedOutputTokens: 4)
        )
        let builder = ContextPromptBuilder(tokenEstimator: PromptWordCountTokenEstimator())

        let prepared = builder.build(request)

        XCTAssertEqual(prepared.messages.map(\.role), [.system, .system, .system, .assistant, .user])
        XCTAssertEqual(prepared.messages.map(\.content), [
            "Answer concisely",
            "Conversation summary:\nPrevious topic was setup.",
            "Relevant context:\nInstall steps",
            "Earlier answer",
            "What next?"
        ])
        XCTAssertEqual(prepared.includedReferences.count, 3)
        XCTAssertTrue(prepared.omittedReferences.isEmpty)
        XCTAssertTrue(prepared.warnings.isEmpty)
        XCTAssertEqual(prepared.metadata["mode"], "deterministic")
        XCTAssertEqual(prepared.estimatedInputTokens, 12)
    }

    func testBuilderAppliesSectionBudgetsAndReportsOmittedReferences() {
        let sourceID = UUID()
        let includedReference = ContextSourceReference(sourceID: sourceID, kind: .span, targetID: UUID(), label: "Included")
        let omittedReference = ContextSourceReference(sourceID: sourceID, kind: .span, targetID: UUID(), label: "Omitted")
        let staleReference = ContextSourceReference(sourceID: sourceID, kind: .span, targetID: UUID(), label: "Stale")
        let request = ContextPromptBuildRequest(
            retrievedChunks: [
                ContextChunk(
                    sourceID: sourceID,
                    level: 0,
                    kind: .raw,
                    text: "small chunk",
                    tokenEstimate: 2,
                    sourceReferences: [includedReference]
                ),
                ContextChunk(
                    sourceID: sourceID,
                    level: 0,
                    kind: .raw,
                    text: "large omitted chunk",
                    tokenEstimate: 3,
                    sourceReferences: [omittedReference]
                ),
                ContextChunk(
                    sourceID: sourceID,
                    level: 0,
                    kind: .raw,
                    text: "stale chunk",
                    tokenEstimate: 1,
                    sourceReferences: [staleReference],
                    isStale: true
                )
            ],
            budget: ContextBudget(
                maximumInputTokens: 10,
                reservedOutputTokens: 2,
                maximumRetrievedSourceTokens: 2
            )
        )
        let builder = ContextPromptBuilder(tokenEstimator: PromptWordCountTokenEstimator())

        let prepared = builder.build(request)

        XCTAssertEqual(prepared.messages.map(\.content), ["Relevant context:\nsmall chunk"])
        XCTAssertEqual(prepared.includedReferences, [includedReference])
        XCTAssertEqual(prepared.omittedReferences, [omittedReference, staleReference])
        XCTAssertEqual(prepared.warnings.map(\.kind), [.tokenBudgetExceeded, .sourceOmitted])
    }

    func testBuilderKeepsNewestRecentTurnsWithinBudgetButOutputsChronologically() {
        let sourceID = UUID()
        let turns = [
            ConversationTurn(sourceID: sourceID, turnIndex: 0, role: .user, content: "old turn", tokenEstimate: 2),
            ConversationTurn(sourceID: sourceID, turnIndex: 1, role: .assistant, content: "middle turn", tokenEstimate: 2),
            ConversationTurn(sourceID: sourceID, turnIndex: 2, role: .user, content: "new turn", tokenEstimate: 2)
        ]
        let request = ContextPromptBuildRequest(
            recentTurns: turns,
            budget: ContextBudget(
                maximumInputTokens: 20,
                reservedOutputTokens: 2,
                maximumRecentTurnTokens: 4
            )
        )
        let builder = ContextPromptBuilder(tokenEstimator: PromptWordCountTokenEstimator())

        let prepared = builder.build(request)

        XCTAssertEqual(prepared.messages.map(\.content), ["middle turn", "new turn"])
        XCTAssertEqual(prepared.includedReferences.map(\.targetID), [turns[2].id, turns[1].id])
        XCTAssertEqual(prepared.omittedReferences.map(\.targetID), [turns[0].id])
    }

    func testBuilderReservesBudgetForFinalUserMessageBeforeOptionalContext() {
        let sourceID = UUID()
        let chunkReference = ContextSourceReference(
            sourceID: sourceID,
            kind: .span,
            targetID: UUID(),
            label: "Optional"
        )
        let request = ContextPromptBuildRequest(
            retrievedChunks: [
                ContextChunk(
                    sourceID: sourceID,
                    level: 0,
                    kind: .raw,
                    text: "optional context",
                    tokenEstimate: 2,
                    sourceReferences: [chunkReference]
                )
            ],
            finalUserMessage: "must fit",
            budget: ContextBudget(maximumInputTokens: 3, reservedOutputTokens: 0)
        )
        let builder = ContextPromptBuilder(tokenEstimator: PromptWordCountTokenEstimator())

        let prepared = builder.build(request)

        XCTAssertEqual(prepared.messages.map(\.content), ["must fit"])
        XCTAssertEqual(prepared.messages.map(\.role), [.user])
        XCTAssertEqual(prepared.estimatedInputTokens, 2)
        XCTAssertEqual(prepared.omittedReferences, [chunkReference])
        XCTAssertEqual(prepared.warnings.map(\.kind), [.tokenBudgetExceeded])
    }

    func testBuilderWarnsWhenFinalUserMessageCannotFitInputBudget() {
        let request = ContextPromptBuildRequest(
            finalUserMessage: "too many words",
            budget: ContextBudget(maximumInputTokens: 2, reservedOutputTokens: 0)
        )
        let builder = ContextPromptBuilder(tokenEstimator: PromptWordCountTokenEstimator())

        let prepared = builder.build(request)

        XCTAssertTrue(prepared.messages.isEmpty)
        XCTAssertEqual(prepared.estimatedInputTokens, 0)
        XCTAssertEqual(prepared.warnings.map(\.kind), [.tokenBudgetExceeded])
        XCTAssertEqual(
            prepared.warnings.first?.message,
            "Final user message exceeded the available input budget."
        )
    }
}

private struct PromptWordCountTokenEstimator: ContextTokenEstimator {
    func estimateTokenCount(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}
#endif
