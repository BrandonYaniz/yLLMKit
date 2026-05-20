import Foundation
import yLLMKit

enum OpenAIStreamEvent: Equatable {
    case textDelta(String)
    case usage(LLMUsage)
    case finishReason(LLMFinishReason)
    case done
}

struct OpenAIServerSentEventParser {
    private var buffer = ""
    private let decoder = JSONDecoder()

    mutating func append(_ data: Data) throws -> [OpenAIStreamEvent] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw LLMProviderError.providerFailed("OpenAI stream emitted non-UTF8 data.")
        }

        buffer += text
        var events: [OpenAIStreamEvent] = []

        while let range = buffer.range(of: "\n\n") {
            let rawEvent = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)
            events.append(contentsOf: try parse(rawEvent))
        }

        return events
    }

    mutating func finish() throws -> [OpenAIStreamEvent] {
        guard !buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            buffer.removeAll()
            return []
        }

        let rawEvent = buffer
        buffer.removeAll()
        return try parse(rawEvent)
    }

    private func parse(_ rawEvent: String) throws -> [OpenAIStreamEvent] {
        let payloads = rawEvent
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> String? in
                guard line.hasPrefix("data:") else {
                    return nil
                }
                return String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            }

        var events: [OpenAIStreamEvent] = []
        for payload in payloads {
            if payload == "[DONE]" {
                events.append(.done)
                continue
            }

            let chunk = try decoder.decode(
                OpenAIChatCompletionChunk.self,
                from: Data(payload.utf8)
            )

            if let usage = chunk.usage {
                events.append(
                    .usage(
                        LLMUsage(
                            inputTokens: usage.promptTokens,
                            outputTokens: usage.completionTokens,
                            totalTokens: usage.totalTokens
                        )
                    )
                )
            }

            for choice in chunk.choices {
                if let content = choice.delta.content, !content.isEmpty {
                    events.append(.textDelta(content))
                }
                if let finishReason = choice.finishReason {
                    events.append(.finishReason(finishReason.llmFinishReason))
                }
            }
        }

        return events
    }
}

private struct OpenAIChatCompletionChunk: Decodable {
    var choices: [Choice]
    var usage: Usage?

    struct Choice: Decodable {
        var delta: Delta
        var finishReason: OpenAIFinishReason?

        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct Delta: Decodable {
        var content: String?
    }

    struct Usage: Decodable {
        var promptTokens: Int?
        var completionTokens: Int?
        var totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

private enum OpenAIFinishReason: String, Decodable {
    case stop
    case length
    case contentFilter = "content_filter"
    case toolCalls = "tool_calls"
    case functionCall = "function_call"

    var llmFinishReason: LLMFinishReason {
        switch self {
        case .stop:
            .stop
        case .length:
            .length
        case .contentFilter, .toolCalls, .functionCall:
            .providerSpecific
        }
    }
}
