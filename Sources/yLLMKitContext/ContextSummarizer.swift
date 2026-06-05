import Foundation
import yLLMKit

public struct ContextChunkSummaryRequest: Sendable {
    public var sourceID: ContextSource.ID
    public var modelID: LLMModelID
    public var chunks: [ContextChunk]
    public var instruction: String?
    public var settings: GenerationSettings
    public var metadata: [String: String]

    public init(
        sourceID: ContextSource.ID,
        modelID: LLMModelID,
        chunks: [ContextChunk],
        instruction: String? = nil,
        settings: GenerationSettings = .balanced,
        metadata: [String: String] = [:]
    ) {
        self.sourceID = sourceID
        self.modelID = modelID
        self.chunks = chunks
        self.instruction = instruction
        self.settings = settings
        self.metadata = metadata
    }
}

public struct ConversationSnapshotSummaryRequest: Sendable {
    public var sourceID: ContextSource.ID
    public var modelID: LLMModelID
    public var turns: [ConversationTurn]
    public var previousSnapshot: ConversationSnapshot?
    public var instruction: String?
    public var settings: GenerationSettings
    public var metadata: [String: String]

    public init(
        sourceID: ContextSource.ID,
        modelID: LLMModelID,
        turns: [ConversationTurn],
        previousSnapshot: ConversationSnapshot? = nil,
        instruction: String? = nil,
        settings: GenerationSettings = .balanced,
        metadata: [String: String] = [:]
    ) {
        self.sourceID = sourceID
        self.modelID = modelID
        self.turns = turns
        self.previousSnapshot = previousSnapshot
        self.instruction = instruction
        self.settings = settings
        self.metadata = metadata
    }
}

public struct ProviderContextSummarizer<Estimator: ContextTokenEstimator>: Sendable {
    public var provider: any LLMProvider
    public var tokenEstimator: Estimator

    public init(
        provider: any LLMProvider,
        tokenEstimator: Estimator
    ) {
        self.provider = provider
        self.tokenEstimator = tokenEstimator
    }

    public func summarizeChunks(
        _ request: ContextChunkSummaryRequest
    ) async throws -> ContextChunk {
        let chunks = request.chunks
            .filter { !$0.isStale }
            .sorted { lhs, rhs in
                if lhs.level == rhs.level {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.level < rhs.level
            }
        guard !chunks.isEmpty else {
            throw ContextSummarizationError.emptyInput
        }

        let summary = try await summarize(
            modelID: request.modelID,
            messages: chunkSummaryMessages(
                chunks: chunks,
                instruction: request.instruction
            ),
            settings: request.settings
        )
        let now = Date()

        return ContextChunk(
            sourceID: request.sourceID,
            level: (chunks.map(\.level).max() ?? 0) + 1,
            kind: .summary,
            text: summary,
            tokenEstimate: tokenEstimator.estimateTokenCount(in: summary),
            sourceReferences: deduplicated(
                chunks.map {
                    ContextSourceReference(
                        sourceID: $0.sourceID,
                        kind: .chunk,
                        targetID: $0.id,
                        label: "Chunk level \($0.level)"
                    )
                } + chunks.flatMap(\.sourceReferences)
            ),
            contentHash: request.metadata["contentHash"],
            createdAt: now,
            updatedAt: now
        )
    }

    public func summarizeConversation(
        _ request: ConversationSnapshotSummaryRequest
    ) async throws -> ConversationSnapshot {
        let turns = request.turns.sorted { $0.turnIndex < $1.turnIndex }
        guard !turns.isEmpty || request.previousSnapshot != nil else {
            throw ContextSummarizationError.emptyInput
        }

        let summary = try await summarize(
            modelID: request.modelID,
            messages: conversationSummaryMessages(
                turns: turns,
                previousSnapshot: request.previousSnapshot,
                instruction: request.instruction
            ),
            settings: request.settings
        )
        let builtThroughReference = turns.last.map(reference(for:))
        let references = deduplicated(
            (request.previousSnapshot.map(\.sourceReferences) ?? []) +
                turns.map(reference(for:))
        )

        return ConversationSnapshot(
            sourceID: request.sourceID,
            summary: summary,
            tokenEstimate: tokenEstimator.estimateTokenCount(in: summary),
            builtThroughReference: builtThroughReference ?? request.previousSnapshot?.builtThroughReference,
            sourceReferences: references,
            contentHash: request.metadata["contentHash"]
        )
    }

    private func summarize(
        modelID: LLMModelID,
        messages: [LLMMessage],
        settings: GenerationSettings
    ) async throws -> String {
        var output = ""
        var completedOutput: String?

        for try await event in provider.streamChat(
            request: LLMChatRequest(
                modelID: modelID,
                messages: messages,
                settings: settings
            )
        ) {
            switch event {
            case .started:
                break
            case .textDelta(let text):
                output += text
            case .completed(let response):
                completedOutput = response.message.content
            }
        }

        let summary = (output.isEmpty ? completedOutput : output)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let summary, !summary.isEmpty else {
            throw ContextSummarizationError.emptySummary
        }
        return summary
    }

    private func chunkSummaryMessages(
        chunks: [ContextChunk],
        instruction: String?
    ) -> [LLMMessage] {
        [
            LLMMessage(
                role: .system,
                content: instruction ?? """
                Summarize the supplied context for future retrieval. Preserve concrete facts, decisions, preferences, identifiers, and unresolved questions. Do not invent details.
                """
            ),
            LLMMessage(
                role: .user,
                content: chunks.enumerated()
                    .map { index, chunk in
                        "[Context \(index + 1), level \(chunk.level)]\n\(chunk.text)"
                    }
                    .joined(separator: "\n\n")
            )
        ]
    }

    private func conversationSummaryMessages(
        turns: [ConversationTurn],
        previousSnapshot: ConversationSnapshot?,
        instruction: String?
    ) -> [LLMMessage] {
        var sections: [String] = []
        if let previousSnapshot {
            sections.append("Previous summary:\n\(previousSnapshot.summary)")
        }
        if !turns.isEmpty {
            sections.append(
                "New conversation turns:\n" +
                    turns.map { "Turn \($0.turnIndex) \($0.role.rawValue): \($0.content)" }
                    .joined(separator: "\n")
            )
        }

        return [
            LLMMessage(
                role: .system,
                content: instruction ?? """
                Build an updated conversation summary for future prompt context. Preserve durable facts, user preferences, decisions, open questions, and important recent state. Do not invent details.
                """
            ),
            LLMMessage(role: .user, content: sections.joined(separator: "\n\n"))
        ]
    }

    private func reference(for turn: ConversationTurn) -> ContextSourceReference {
        ContextSourceReference(
            sourceID: turn.sourceID,
            kind: .turn,
            targetID: turn.id,
            label: "Turn \(turn.turnIndex)"
        )
    }

    private func deduplicated(
        _ references: [ContextSourceReference]
    ) -> [ContextSourceReference] {
        var seen: Set<ContextSourceReference> = []
        var result: [ContextSourceReference] = []
        for reference in references where !seen.contains(reference) {
            seen.insert(reference)
            result.append(reference)
        }
        return result
    }
}

public extension ProviderContextSummarizer where Estimator == ApproximateContextTokenEstimator {
    init(
        provider: any LLMProvider,
        tokenEstimator: ApproximateContextTokenEstimator = ApproximateContextTokenEstimator()
    ) {
        self.provider = provider
        self.tokenEstimator = tokenEstimator
    }
}

public enum ContextSummarizationError: Error, Hashable, Sendable {
    case emptyInput
    case emptySummary
}
