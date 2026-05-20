import Foundation
import MLXLMCommon
import yLLMKit

public final class MLXSession: LLMSession, @unchecked Sendable {
    public let id: UUID
    public let model: ModelDescriptor

    private let container: ModelContainer
    private let baseInstructions: String?
    private let state = GenerationState()

    public init(
        id: UUID = UUID(),
        model: ModelDescriptor,
        container: ModelContainer,
        configuration: SessionConfiguration
    ) {
        self.id = id
        self.model = model
        self.container = container
        self.baseInstructions = configuration.systemPrompt
    }

    public func streamResponse(
        to messages: [LLMMessage],
        settings: GenerationSettings
    ) -> AsyncThrowingStream<LLMToken, Error> {
        AsyncThrowingStream { continuation in
            guard let generationID = state.beginGeneration() else {
                continuation.finish(
                    throwing: LLMError.invalidRequest("Session already has an active generation.")
                )
                return
            }

            let task = Task {
                do {
                    defer {
                        state.finishGeneration(generationID)
                    }

                    var index = 0
                    let request = try MLXPromptBuilder.promptRequest(from: messages)
                    var stopFilter = StopSequenceFilter(
                        stopSequences: stopSequences(from: settings)
                    )
                    let session = ChatSession(
                        container,
                        instructions: combinedInstructions(request.instructions),
                        history: request.history,
                        generateParameters: GenerateParameters(settings: settings)
                    )

                    for try await chunk in session.streamResponse(
                        to: request.prompt.content,
                        role: request.prompt.role,
                        images: [],
                        videos: []
                    ) {
                        if state.isCancelled(generationID) || Task.isCancelled {
                            continuation.finish(throwing: LLMError.generationCancelled)
                            return
                        }

                        let result = stopFilter.append(chunk)
                        if let text = result.text, !text.isEmpty {
                            continuation.yield(
                                LLMToken(
                                    text: text,
                                    index: index
                                )
                            )
                            index += 1
                        }
                        if result.shouldStop {
                            continuation.finish()
                            return
                        }
                    }
                    if let text = stopFilter.finish(), !text.isEmpty {
                        continuation.yield(
                            LLMToken(
                                text: text,
                                index: index
                            )
                        )
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                self.state.cancel(generationID)
                task.cancel()
            }
        }
    }

    public func cancel() {
        state.cancelActiveGeneration()
    }

    private func combinedInstructions(_ requestInstructions: String?) -> String? {
        [baseInstructions, requestInstructions]
            .compactMap { value in
                value?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
            .nilIfEmpty
    }

    private func stopSequences(from settings: GenerationSettings) -> [String] {
        var seen = Set<String>()
        return (model.defaultSettings.stopSequences + settings.stopSequences)
            .filter { sequence in
                !sequence.isEmpty && seen.insert(sequence).inserted
            }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private struct StopSequenceFilter {
    private let stopSequences: [String]
    private let retainedSuffixLength: Int
    private var buffer = ""

    init(stopSequences: [String]) {
        self.stopSequences = stopSequences
        self.retainedSuffixLength = max(0, (stopSequences.map(\.count).max() ?? 1) - 1)
    }

    mutating func append(_ text: String) -> (text: String?, shouldStop: Bool) {
        guard !stopSequences.isEmpty else {
            return (text, false)
        }

        buffer += text
        if let stopRange = earliestStopRange(in: buffer) {
            let output = String(buffer[..<stopRange.lowerBound])
            buffer.removeAll(keepingCapacity: true)
            return (output, true)
        }

        guard buffer.count > retainedSuffixLength else {
            return (nil, false)
        }

        let splitIndex = buffer.index(buffer.endIndex, offsetBy: -retainedSuffixLength)
        let output = String(buffer[..<splitIndex])
        buffer.removeSubrange(..<splitIndex)
        return (output, false)
    }

    mutating func finish() -> String? {
        defer { buffer.removeAll(keepingCapacity: true) }
        return buffer.isEmpty ? nil : buffer
    }

    private func earliestStopRange(in text: String) -> Range<String.Index>? {
        stopSequences
            .compactMap { text.range(of: $0) }
            .min { $0.lowerBound < $1.lowerBound }
    }
}

final class GenerationState: @unchecked Sendable {
    private let lock = NSLock()
    private var activeGenerationID: UUID?
    private var cancelledGenerationIDs: Set<UUID> = []

    func beginGeneration() -> UUID? {
        lock.withLock {
            guard activeGenerationID == nil else {
                return nil
            }

            let id = UUID()
            activeGenerationID = id
            return id
        }
    }

    func cancel(_ id: UUID) {
        lock.withLock {
            _ = cancelledGenerationIDs.insert(id)
        }
    }

    func cancelActiveGeneration() {
        lock.withLock {
            if let activeGenerationID {
                _ = cancelledGenerationIDs.insert(activeGenerationID)
            }
        }
    }

    func isCancelled(_ id: UUID) -> Bool {
        lock.withLock {
            cancelledGenerationIDs.contains(id)
        }
    }

    func finishGeneration(_ id: UUID) {
        lock.withLock {
            guard activeGenerationID == id else {
                cancelledGenerationIDs.remove(id)
                return
            }

            activeGenerationID = nil
            cancelledGenerationIDs.remove(id)
        }
    }
}

private extension GenerateParameters {
    init(settings: GenerationSettings) {
        self.init(
            maxTokens: settings.maxTokens,
            temperature: Float(settings.temperature),
            topP: Float(settings.topP),
            repetitionPenalty: settings.repetitionPenalty.map(Float.init)
        )
    }
}
