#if canImport(XCTest)
import Foundation
import XCTest
import yLLMKit
import yLLMKitContext

final class yLLMKitContextTests: XCTestCase {
    func testContextSourceRoundTripsThroughCodable() throws {
        let source = ContextSource(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            kind: .markdownDocument,
            title: "Project Notes",
            contentHash: "hash",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2),
            metadata: ["path": "notes.md"]
        )

        let data = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(ContextSource.self, from: data)

        XCTAssertEqual(decoded, source)
    }

    func testConversationTurnUsesCoreRoles() throws {
        let sourceID = UUID()
        let turn = ConversationTurn(
            sourceID: sourceID,
            turnIndex: 2,
            role: .assistant,
            content: "A concise answer.",
            tokenEstimate: 4,
            createdAt: Date(timeIntervalSince1970: 3)
        )

        let data = try JSONEncoder().encode(turn)
        let decoded = try JSONDecoder().decode(ConversationTurn.self, from: data)

        XCTAssertEqual(decoded.role, .assistant)
        XCTAssertEqual(decoded.sourceID, sourceID)
        XCTAssertEqual(decoded.tokenEstimate, 4)
    }

    func testSourceReferencesSurviveChunksSnapshotsAndMemory() throws {
        let sourceID = UUID()
        let turnID = UUID()
        let spanID = UUID()
        let turnReference = ContextSourceReference(
            sourceID: sourceID,
            kind: .turn,
            targetID: turnID,
            label: "Turn 1"
        )
        let spanReference = ContextSourceReference(
            sourceID: sourceID,
            kind: .span,
            targetID: spanID,
            startOffset: 10,
            endOffset: 42,
            label: "Paragraph"
        )
        let chunk = ContextChunk(
            sourceID: sourceID,
            level: 0,
            kind: .raw,
            text: "Important source text.",
            tokenEstimate: 5,
            sourceReferences: [turnReference, spanReference]
        )
        let snapshot = ConversationSnapshot(
            sourceID: sourceID,
            summary: "Conversation summary.",
            tokenEstimate: 3,
            builtThroughReference: turnReference,
            sourceReferences: [spanReference]
        )
        let memory = MemoryItem(
            sourceID: sourceID,
            kind: .fact,
            text: "The user prefers concise answers.",
            sourceReferences: [turnReference],
            confidence: .high
        )

        let encoded = try JSONEncoder().encode([chunk.sourceReferences, snapshot.sourceReferences, memory.sourceReferences])
        let decoded = try JSONDecoder().decode([[ContextSourceReference]].self, from: encoded)

        XCTAssertEqual(decoded[0], [turnReference, spanReference])
        XCTAssertEqual(decoded[1], [spanReference])
        XCTAssertEqual(decoded[2], [turnReference])
    }

    func testPreparedContextCarriesMessagesWarningsAndOmittedReferences() throws {
        let sourceID = UUID()
        let reference = ContextSourceReference(
            sourceID: sourceID,
            kind: .source,
            label: "Large source"
        )
        let warning = ContextBuildWarning(
            kind: .tokenBudgetExceeded,
            message: "Source was too large.",
            sourceReference: reference
        )
        let prepared = PreparedContext(
            messages: [
                LLMMessage(role: .system, content: "Use supplied context."),
                LLMMessage(role: .user, content: "Summarize this.")
            ],
            estimatedInputTokens: 128,
            includedReferences: [],
            omittedReferences: [reference],
            warnings: [warning],
            metadata: ["mode": "deterministic"]
        )

        let data = try JSONEncoder().encode(prepared)
        let decoded = try JSONDecoder().decode(PreparedContext.self, from: data)

        XCTAssertEqual(decoded, prepared)
        XCTAssertEqual(decoded.messages.map(\.role), [.system, .user])
        XCTAssertEqual(decoded.warnings.first?.kind, .tokenBudgetExceeded)
    }

    func testContextBudgetComputesAvailableInputTokens() {
        let budget = ContextBudget(
            maximumInputTokens: 4096,
            reservedOutputTokens: 1024,
            maximumInstructionTokens: 256,
            maximumRecentTurnTokens: 1024,
            maximumSnapshotTokens: 512,
            maximumRetrievedSourceTokens: 1536
        )

        XCTAssertEqual(budget.availableInputTokens, 3072)
        XCTAssertEqual(budget.maximumInstructionTokens, 256)
        XCTAssertEqual(budget.maximumRecentTurnTokens, 1024)
        XCTAssertEqual(budget.maximumSnapshotTokens, 512)
        XCTAssertEqual(budget.maximumRetrievedSourceTokens, 1536)
    }

    func testContextBudgetNeverReturnsNegativeAvailableInputTokens() {
        let budget = ContextBudget(
            maximumInputTokens: 100,
            reservedOutputTokens: 200
        )

        XCTAssertEqual(budget.availableInputTokens, 0)
    }

    func testPolicyEnumsRoundTrip() throws {
        let rebuildPolicy = ContextRebuildPolicy.manual
        let powerPolicy = ContextPowerPolicy.disableRebuildsOnBattery

        let rebuildData = try JSONEncoder().encode(rebuildPolicy)
        let powerData = try JSONEncoder().encode(powerPolicy)

        XCTAssertEqual(try JSONDecoder().decode(ContextRebuildPolicy.self, from: rebuildData), rebuildPolicy)
        XCTAssertEqual(try JSONDecoder().decode(ContextPowerPolicy.self, from: powerData), powerPolicy)
    }
}
#endif
