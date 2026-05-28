import Foundation
import yLLMKit

public struct ContextPromptBuildRequest: Codable, Hashable, Sendable {
    public var systemPrompt: String?
    public var snapshot: ConversationSnapshot?
    public var retrievedChunks: [ContextChunk]
    public var recentTurns: [ConversationTurn]
    public var finalUserMessage: String?
    public var budget: ContextBudget
    public var metadata: [String: String]

    public init(
        systemPrompt: String? = nil,
        snapshot: ConversationSnapshot? = nil,
        retrievedChunks: [ContextChunk] = [],
        recentTurns: [ConversationTurn] = [],
        finalUserMessage: String? = nil,
        budget: ContextBudget,
        metadata: [String: String] = [:]
    ) {
        self.systemPrompt = systemPrompt
        self.snapshot = snapshot
        self.retrievedChunks = retrievedChunks
        self.recentTurns = recentTurns
        self.finalUserMessage = finalUserMessage
        self.budget = budget
        self.metadata = metadata
    }
}

public struct ContextPromptBuilder<Estimator: ContextTokenEstimator>: Sendable {
    public var tokenEstimator: Estimator

    public init(tokenEstimator: Estimator) {
        self.tokenEstimator = tokenEstimator
    }

    public func build(_ request: ContextPromptBuildRequest) -> PreparedContext {
        var state = BuildState(remainingTokens: request.budget.availableInputTokens)
        var messages: [LLMMessage] = []
        let reservedFinalUserMessage = reserveFinalUserMessage(
            nonEmpty(request.finalUserMessage),
            state: &state
        )

        if let systemPrompt = nonEmpty(request.systemPrompt) {
            appendSystemPrompt(
                systemPrompt,
                budget: request.budget.maximumInstructionTokens,
                state: &state,
                messages: &messages
            )
        }

        if let snapshot = request.snapshot {
            appendSnapshot(
                snapshot,
                budget: request.budget.maximumSnapshotTokens,
                state: &state,
                messages: &messages
            )
        }

        appendRetrievedChunks(
            request.retrievedChunks,
            budget: request.budget.maximumRetrievedSourceTokens,
            state: &state,
            messages: &messages
        )

        appendRecentTurns(
            request.recentTurns,
            budget: request.budget.maximumRecentTurnTokens,
            state: &state,
            messages: &messages
        )

        if let reservedFinalUserMessage {
            appendReservedFinalUserMessage(reservedFinalUserMessage, messages: &messages)
        }

        var metadata = request.metadata
        metadata["mode"] = metadata["mode"] ?? "deterministic"

        return PreparedContext(
            messages: messages,
            estimatedInputTokens: request.budget.availableInputTokens - state.remainingTokens,
            includedReferences: state.includedReferences,
            omittedReferences: state.omittedReferences,
            warnings: state.warnings,
            metadata: metadata
        )
    }

    private func reserveFinalUserMessage(
        _ message: String?,
        state: inout BuildState
    ) -> ReservedFinalUserMessage? {
        guard let message else {
            return nil
        }

        let tokenEstimate = estimate(message)
        guard tokenEstimate <= state.remainingTokens else {
            state.warnings.append(
                ContextBuildWarning(
                    kind: .tokenBudgetExceeded,
                    message: "Final user message exceeded the available input budget."
                )
            )
            return nil
        }

        state.remainingTokens -= tokenEstimate
        return ReservedFinalUserMessage(content: message)
    }

    private func appendSystemPrompt(
        _ prompt: String,
        budget: Int?,
        state: inout BuildState,
        messages: inout [LLMMessage]
    ) {
        let tokenEstimate = estimate(prompt)
        guard fits(tokenEstimate, sectionBudget: budget, state: state) else {
            state.warnings.append(
                ContextBuildWarning(
                    kind: .tokenBudgetExceeded,
                    message: "System prompt exceeded the available instruction budget."
                )
            )
            return
        }

        messages.append(LLMMessage(role: .system, content: prompt))
        state.remainingTokens -= tokenEstimate
    }

    private func appendSnapshot(
        _ snapshot: ConversationSnapshot,
        budget: Int?,
        state: inout BuildState,
        messages: inout [LLMMessage]
    ) {
        let tokenEstimate = snapshot.tokenEstimate ?? estimate(snapshot.summary)
        guard fits(tokenEstimate, sectionBudget: budget, state: state) else {
            omit(snapshot.sourceReferences, state: &state, message: "Conversation snapshot exceeded the available snapshot budget.")
            return
        }

        messages.append(LLMMessage(role: .system, content: "Conversation summary:\n\(snapshot.summary)"))
        state.remainingTokens -= tokenEstimate
        state.includedReferences.append(contentsOf: snapshot.sourceReferences)
    }

    private func appendRetrievedChunks(
        _ chunks: [ContextChunk],
        budget: Int?,
        state: inout BuildState,
        messages: inout [LLMMessage]
    ) {
        var remainingSectionTokens = budget
        var includedContext: [String] = []

        for chunk in chunks where !chunk.isStale {
            let tokenEstimate = chunk.tokenEstimate ?? estimate(chunk.text)
            guard fits(tokenEstimate, sectionBudget: remainingSectionTokens, state: state) else {
                omit(chunk.sourceReferences, state: &state, message: "A retrieved context chunk exceeded the available source budget.")
                continue
            }

            includedContext.append(chunk.text)
            state.remainingTokens -= tokenEstimate
            remainingSectionTokens = remainingSectionTokens.map { $0 - tokenEstimate }
            state.includedReferences.append(contentsOf: chunk.sourceReferences)
        }

        for staleChunk in chunks where staleChunk.isStale {
            omit(staleChunk.sourceReferences, state: &state, kind: .sourceOmitted, message: "A stale context chunk was omitted.")
        }

        if !includedContext.isEmpty {
            messages.append(LLMMessage(role: .system, content: "Relevant context:\n\(includedContext.joined(separator: "\n\n"))"))
        }
    }

    private func appendRecentTurns(
        _ turns: [ConversationTurn],
        budget: Int?,
        state: inout BuildState,
        messages: inout [LLMMessage]
    ) {
        var remainingSectionTokens = budget
        var selected: [ConversationTurn] = []

        for turn in turns.sorted(by: { $0.turnIndex > $1.turnIndex }) {
            let tokenEstimate = turn.tokenEstimate ?? estimate(turn.content)
            guard fits(tokenEstimate, sectionBudget: remainingSectionTokens, state: state) else {
                omit([reference(for: turn)], state: &state, message: "A recent conversation turn exceeded the available recent-turn budget.")
                continue
            }

            selected.append(turn)
            state.remainingTokens -= tokenEstimate
            remainingSectionTokens = remainingSectionTokens.map { $0 - tokenEstimate }
            state.includedReferences.append(reference(for: turn))
        }

        messages.append(
            contentsOf: selected
                .sorted(by: { $0.turnIndex < $1.turnIndex })
                .map { LLMMessage(role: $0.role, content: $0.content) }
        )
    }

    private func appendReservedFinalUserMessage(
        _ message: ReservedFinalUserMessage,
        messages: inout [LLMMessage]
    ) {
        messages.append(LLMMessage(role: .user, content: message.content))
    }

    private func fits(_ tokenEstimate: Int, sectionBudget: Int?, state: BuildState) -> Bool {
        tokenEstimate <= state.remainingTokens && tokenEstimate <= (sectionBudget ?? tokenEstimate)
    }

    private func omit(
        _ references: [ContextSourceReference],
        state: inout BuildState,
        kind: ContextBuildWarningKind = .tokenBudgetExceeded,
        message: String
    ) {
        state.omittedReferences.append(contentsOf: references)
        state.warnings.append(ContextBuildWarning(kind: kind, message: message, sourceReference: references.first))
    }

    private func reference(for turn: ConversationTurn) -> ContextSourceReference {
        ContextSourceReference(
            sourceID: turn.sourceID,
            kind: .turn,
            targetID: turn.id,
            label: "Turn \(turn.turnIndex)"
        )
    }

    private func estimate(_ text: String) -> Int {
        tokenEstimator.estimateTokenCount(in: text)
    }

    private func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }
}

public extension ContextPromptBuilder where Estimator == ApproximateContextTokenEstimator {
    init(tokenEstimator: ApproximateContextTokenEstimator = ApproximateContextTokenEstimator()) {
        self.tokenEstimator = tokenEstimator
    }
}

private struct ReservedFinalUserMessage {
    var content: String
}

private struct BuildState {
    var remainingTokens: Int
    var includedReferences: [ContextSourceReference] = []
    var omittedReferences: [ContextSourceReference] = []
    var warnings: [ContextBuildWarning] = []
}
