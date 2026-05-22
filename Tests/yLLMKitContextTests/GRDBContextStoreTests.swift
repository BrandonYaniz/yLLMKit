#if canImport(XCTest)
import Foundation
import XCTest
import yLLMKit
import yLLMKitContext

final class GRDBContextStoreTests: XCTestCase {
    func testFreshDatabaseCanCreateAndReadSource() async throws {
        let store = try GRDBContextStore(inMemoryIdentifier: UUID().uuidString)
        let source = ContextSource(
            kind: .plainTextDocument,
            title: "Source",
            contentHash: "hash",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 2),
            metadata: ["origin": "test"]
        )

        try await store.createSource(source)
        let stored = try await store.source(id: source.id)

        XCTAssertEqual(stored, source)
    }

    func testAppendAndReadTranscriptTurns() async throws {
        let store = try GRDBContextStore(inMemoryIdentifier: UUID().uuidString)
        let source = ContextSource(kind: .conversation, title: "Chat")
        try await store.createSource(source)
        let first = ConversationTurn(
            sourceID: source.id,
            turnIndex: 0,
            role: .user,
            content: "Hello",
            tokenEstimate: 1,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let second = ConversationTurn(
            sourceID: source.id,
            turnIndex: 1,
            role: .assistant,
            content: "Hi",
            tokenEstimate: 1,
            createdAt: Date(timeIntervalSince1970: 2)
        )

        try await store.appendTurn(second)
        try await store.appendTurn(first)

        let turns = try await store.turns(for: source.id)
        XCTAssertEqual(turns, [first, second])
    }

    func testSaveReadAndMarkChunkStale() async throws {
        let store = try GRDBContextStore(inMemoryIdentifier: UUID().uuidString)
        let source = ContextSource(kind: .plainTextDocument, title: "Doc")
        try await store.createSource(source)
        let reference = ContextSourceReference(
            sourceID: source.id,
            kind: .source,
            label: "Doc"
        )
        let chunk = ContextChunk(
            sourceID: source.id,
            level: 0,
            kind: .raw,
            text: "Alpha beta context.",
            tokenEstimate: 3,
            sourceReferences: [reference],
            contentHash: "chunk-hash",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )

        try await store.saveChunk(chunk)
        let storedChunk = try await store.chunk(id: chunk.id)
        XCTAssertEqual(storedChunk, chunk)

        try await store.markChunkStale(id: chunk.id)
        let staleChunkOptional = try await store.chunk(id: chunk.id)
        let staleChunk = try XCTUnwrap(staleChunkOptional)
        XCTAssertTrue(staleChunk.isStale)
        XCTAssertEqual(staleChunk.sourceReferences, [reference])
    }

    func testLatestSnapshotReturnsNewestSnapshot() async throws {
        let store = try GRDBContextStore(inMemoryIdentifier: UUID().uuidString)
        let source = ContextSource(kind: .conversation, title: "Chat")
        try await store.createSource(source)
        let older = ConversationSnapshot(
            sourceID: source.id,
            summary: "Older",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let newer = ConversationSnapshot(
            sourceID: source.id,
            summary: "Newer",
            createdAt: Date(timeIntervalSince1970: 2)
        )

        try await store.saveSnapshot(older)
        try await store.saveSnapshot(newer)

        let latest = try await store.latestSnapshot(for: source.id)
        XCTAssertEqual(latest, newer)
    }

    func testMemoryItemsAndSearchAreIndexed() async throws {
        let store = try GRDBContextStore(inMemoryIdentifier: UUID().uuidString)
        let source = ContextSource(kind: .conversation, title: "Chat")
        try await store.createSource(source)
        let item = MemoryItem(
            sourceID: source.id,
            kind: .preference,
            text: "The user prefers terse answers.",
            confidence: .high
        )

        try await store.saveMemoryItem(item)
        let results = try await store.search(
            ContextSearchQuery(text: "terse", sourceID: source.id)
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.sourceID, source.id)
        XCTAssertEqual(results.first?.recordID, item.id)
        XCTAssertEqual(results.first?.recordType, .memoryItem)
        XCTAssertEqual(results.first?.text, "The user prefers terse answers.")
    }

    func testSearchIndexesTurnsSpansChunksAndSnapshots() async throws {
        let store = try GRDBContextStore(inMemoryIdentifier: UUID().uuidString)
        let source = ContextSource(kind: .plainTextDocument, title: "Manual")
        try await store.createSource(source)
        try await store.appendTurn(
            ConversationTurn(
                sourceID: source.id,
                turnIndex: 0,
                role: .user,
                content: "Ask about orchids."
            )
        )
        try await store.saveSpan(
            ContextSourceSpan(
                sourceID: source.id,
                startOffset: 0,
                endOffset: 20,
                sectionTitle: "Plants",
                text: "Orchids need careful watering."
            )
        )
        try await store.saveChunk(
            ContextChunk(
                sourceID: source.id,
                level: 0,
                kind: .raw,
                text: "Orchids like indirect light."
            )
        )
        try await store.saveSnapshot(
            ConversationSnapshot(
                sourceID: source.id,
                summary: "Orchids were discussed."
            )
        )

        let results = try await store.search(ContextSearchQuery(text: "orchids", sourceID: source.id, limit: 10))
        XCTAssertEqual(Set(results.map(\.recordType)), [.turn, .span, .chunk, .snapshot])
    }
}
#endif
