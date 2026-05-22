#if canImport(XCTest)
import Foundation
import XCTest
import yLLMKitContext

final class ContextChunkerTests: XCTestCase {
    func testApproximateEstimatorCountsNonEmptyText() {
        let estimator = ApproximateContextTokenEstimator(charactersPerToken: 4)

        XCTAssertEqual(estimator.estimateTokenCount(in: ""), 0)
        XCTAssertEqual(estimator.estimateTokenCount(in: "   \n"), 0)
        XCTAssertEqual(estimator.estimateTokenCount(in: "abcd"), 1)
        XCTAssertEqual(estimator.estimateTokenCount(in: "abcde"), 2)
    }

    func testChunkerReturnsEmptyResultForWhitespaceOnlyText() throws {
        let sourceID = UUID()
        let chunker = ContextTextChunker(tokenEstimator: WordCountTokenEstimator())

        let result = try chunker.chunk(sourceID: sourceID, text: " \n\t ")

        XCTAssertTrue(result.spans.isEmpty)
        XCTAssertTrue(result.chunks.isEmpty)
    }

    func testChunkerSplitsByEstimatedTokenBudget() throws {
        let sourceID = UUID()
        let createdAt = Date(timeIntervalSince1970: 42)
        let chunker = ContextTextChunker(tokenEstimator: WordCountTokenEstimator())

        let result = try chunker.chunk(
            sourceID: sourceID,
            text: "one two three four five",
            sectionTitle: "Numbers",
            options: ContextChunkingOptions(maximumTokensPerChunk: 2, overlapTokens: 0),
            createdAt: createdAt
        )

        XCTAssertEqual(result.chunks.map(\.text), ["one two", "three four", "five"])
        XCTAssertEqual(result.chunks.map(\.tokenEstimate), [2, 2, 1])
        XCTAssertEqual(result.spans.map(\.startOffset), [0, 8, 19])
        XCTAssertEqual(result.spans.map(\.endOffset), [7, 18, 23])
        XCTAssertEqual(result.chunks.map(\.createdAt), [createdAt, createdAt, createdAt])
        XCTAssertEqual(result.chunks.first?.sourceReferences.first?.targetID, result.spans.first?.id)
        XCTAssertEqual(result.chunks.first?.sourceReferences.first?.label, "Numbers")
        XCTAssertEqual(result.chunks.first?.sourceReferences.first?.kind, .span)
    }

    func testChunkerPreservesOverlapBetweenChunks() throws {
        let sourceID = UUID()
        let chunker = ContextTextChunker(tokenEstimator: WordCountTokenEstimator())

        let result = try chunker.chunk(
            sourceID: sourceID,
            text: "one two three four five",
            options: ContextChunkingOptions(maximumTokensPerChunk: 3, overlapTokens: 1)
        )

        XCTAssertEqual(result.chunks.map(\.text), ["one two three", "three four five"])
    }

    func testChunkerStillEmitsOversizedSingleWords() throws {
        let sourceID = UUID()
        let chunker = ContextTextChunker(tokenEstimator: WordCountTokenEstimator())

        let result = try chunker.chunk(
            sourceID: sourceID,
            text: "oversized",
            options: ContextChunkingOptions(maximumTokensPerChunk: 1, overlapTokens: 0)
        )

        XCTAssertEqual(result.chunks.map(\.text), ["oversized"])
        XCTAssertEqual(result.chunks.map(\.tokenEstimate), [1])
    }

    func testChunkerRejectsInvalidOptions() {
        let chunker = ContextTextChunker(tokenEstimator: WordCountTokenEstimator())

        XCTAssertThrowsError(
            try chunker.chunk(
                sourceID: UUID(),
                text: "one two",
                options: ContextChunkingOptions(maximumTokensPerChunk: 0, overlapTokens: 0)
            )
        ) { error in
            XCTAssertEqual(error as? ContextChunkerError, .invalidMaximumTokensPerChunk(0))
        }

        XCTAssertThrowsError(
            try chunker.chunk(
                sourceID: UUID(),
                text: "one two",
                options: ContextChunkingOptions(maximumTokensPerChunk: 2, overlapTokens: 2)
            )
        ) { error in
            XCTAssertEqual(error as? ContextChunkerError, .overlapMustBeSmallerThanChunkSize)
        }
    }
}

private struct WordCountTokenEstimator: ContextTokenEstimator {
    func estimateTokenCount(in text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}
#endif
