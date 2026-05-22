import Foundation

public protocol ContextTokenEstimator: Sendable {
    func estimateTokenCount(in text: String) -> Int
}

public struct ApproximateContextTokenEstimator: ContextTokenEstimator {
    public var charactersPerToken: Int

    public init(charactersPerToken: Int = 4) {
        self.charactersPerToken = max(1, charactersPerToken)
    }

    public func estimateTokenCount(in text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return 0
        }
        return max(1, Int(ceil(Double(trimmed.count) / Double(charactersPerToken))))
    }
}

public struct ContextChunkingOptions: Codable, Hashable, Sendable {
    public var maximumTokensPerChunk: Int
    public var overlapTokens: Int
    public var chunkLevel: Int
    public var chunkKind: ContextChunkKind

    public init(
        maximumTokensPerChunk: Int = 512,
        overlapTokens: Int = 64,
        chunkLevel: Int = 0,
        chunkKind: ContextChunkKind = .raw
    ) {
        self.maximumTokensPerChunk = maximumTokensPerChunk
        self.overlapTokens = overlapTokens
        self.chunkLevel = chunkLevel
        self.chunkKind = chunkKind
    }
}

public struct ContextChunkingResult: Codable, Hashable, Sendable {
    public var spans: [ContextSourceSpan]
    public var chunks: [ContextChunk]

    public init(spans: [ContextSourceSpan], chunks: [ContextChunk]) {
        self.spans = spans
        self.chunks = chunks
    }
}

public struct ContextTextChunker<Estimator: ContextTokenEstimator>: Sendable {
    public var tokenEstimator: Estimator

    public init(tokenEstimator: Estimator) {
        self.tokenEstimator = tokenEstimator
    }

    public func chunk(
        sourceID: ContextSource.ID,
        text: String,
        sectionTitle: String? = nil,
        options: ContextChunkingOptions = ContextChunkingOptions(),
        createdAt: Date = Date()
    ) throws -> ContextChunkingResult {
        try validate(options)

        let words = wordRanges(in: text)
        guard !words.isEmpty else {
            return ContextChunkingResult(spans: [], chunks: [])
        }

        var spans: [ContextSourceSpan] = []
        var chunks: [ContextChunk] = []
        var startWordIndex = 0

        while startWordIndex < words.count {
            let endWordIndex = chunkEndIndex(
                words: words,
                text: text,
                startWordIndex: startWordIndex,
                maximumTokens: options.maximumTokensPerChunk
            )
            let start = words[startWordIndex].lowerBound
            let end = words[endWordIndex - 1].upperBound
            let chunkText = String(text[start..<end])
            let tokenEstimate = tokenEstimator.estimateTokenCount(in: chunkText)
            let startOffset = text.utf16.distance(from: text.utf16.startIndex, to: start.samePosition(in: text.utf16)!)
            let endOffset = text.utf16.distance(from: text.utf16.startIndex, to: end.samePosition(in: text.utf16)!)

            let span = ContextSourceSpan(
                sourceID: sourceID,
                startOffset: startOffset,
                endOffset: endOffset,
                sectionTitle: sectionTitle,
                text: chunkText,
                tokenEstimate: tokenEstimate
            )
            let reference = ContextSourceReference(
                sourceID: sourceID,
                kind: .span,
                targetID: span.id,
                startOffset: startOffset,
                endOffset: endOffset,
                label: sectionTitle
            )
            let chunk = ContextChunk(
                sourceID: sourceID,
                level: options.chunkLevel,
                kind: options.chunkKind,
                text: chunkText,
                tokenEstimate: tokenEstimate,
                sourceReferences: [reference],
                createdAt: createdAt,
                updatedAt: createdAt
            )

            spans.append(span)
            chunks.append(chunk)

            if endWordIndex == words.count {
                break
            }

            startWordIndex = nextStartIndex(
                words: words,
                text: text,
                previousStartIndex: startWordIndex,
                previousEndIndex: endWordIndex,
                overlapTokens: options.overlapTokens
            )
        }

        return ContextChunkingResult(spans: spans, chunks: chunks)
    }

    private func validate(_ options: ContextChunkingOptions) throws {
        guard options.maximumTokensPerChunk > 0 else {
            throw ContextChunkerError.invalidMaximumTokensPerChunk(options.maximumTokensPerChunk)
        }
        guard options.overlapTokens >= 0 else {
            throw ContextChunkerError.invalidOverlapTokens(options.overlapTokens)
        }
        guard options.overlapTokens < options.maximumTokensPerChunk else {
            throw ContextChunkerError.overlapMustBeSmallerThanChunkSize
        }
    }

    private func wordRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var index = text.startIndex

        while index < text.endIndex {
            while index < text.endIndex, text[index].isWhitespace {
                index = text.index(after: index)
            }
            guard index < text.endIndex else {
                break
            }
            let start = index
            while index < text.endIndex, !text[index].isWhitespace {
                index = text.index(after: index)
            }
            ranges.append(start..<index)
        }

        return ranges
    }

    private func chunkEndIndex(
        words: [Range<String.Index>],
        text: String,
        startWordIndex: Int,
        maximumTokens: Int
    ) -> Int {
        var endWordIndex = startWordIndex + 1

        while endWordIndex <= words.count {
            let candidateEnd = words[endWordIndex - 1].upperBound
            let candidateText = String(text[words[startWordIndex].lowerBound..<candidateEnd])
            let estimate = tokenEstimator.estimateTokenCount(in: candidateText)

            if estimate > maximumTokens {
                return max(startWordIndex + 1, endWordIndex - 1)
            }

            endWordIndex += 1
        }

        return words.count
    }

    private func nextStartIndex(
        words: [Range<String.Index>],
        text: String,
        previousStartIndex: Int,
        previousEndIndex: Int,
        overlapTokens: Int
    ) -> Int {
        guard overlapTokens > 0 else {
            return previousEndIndex
        }

        var overlapStartIndex = previousEndIndex - 1
        while overlapStartIndex > previousStartIndex {
            let overlapText = String(text[words[overlapStartIndex].lowerBound..<words[previousEndIndex - 1].upperBound])
            if tokenEstimator.estimateTokenCount(in: overlapText) >= overlapTokens {
                break
            }
            overlapStartIndex -= 1
        }

        if overlapStartIndex <= previousStartIndex {
            return previousEndIndex
        }
        return overlapStartIndex
    }
}

public extension ContextTextChunker where Estimator == ApproximateContextTokenEstimator {
    init(tokenEstimator: ApproximateContextTokenEstimator = ApproximateContextTokenEstimator()) {
        self.tokenEstimator = tokenEstimator
    }
}

public enum ContextChunkerError: Error, Hashable, Sendable {
    case invalidMaximumTokensPerChunk(Int)
    case invalidOverlapTokens(Int)
    case overlapMustBeSmallerThanChunkSize
}
