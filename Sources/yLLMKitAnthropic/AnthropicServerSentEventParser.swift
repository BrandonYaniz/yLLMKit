import Foundation
import yLLMKit

enum AnthropicStreamEvent: Equatable {
    case textDelta(String)
    case usage(LLMUsage)
    case finishReason(LLMFinishReason)
    case done
}

struct AnthropicServerSentEventParser {
    private var buffer = ""
    private let decoder = JSONDecoder()

    mutating func append(_ data: Data) throws -> [AnthropicStreamEvent] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw LLMProviderError.providerFailed("Anthropic stream emitted non-UTF8 data.")
        }

        buffer += text
        var events: [AnthropicStreamEvent] = []

        while let range = buffer.range(of: "\n\n") {
            let rawEvent = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)
            events.append(contentsOf: try parse(rawEvent))
        }

        return events
    }

    mutating func finish() throws -> [AnthropicStreamEvent] {
        guard !buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            buffer.removeAll()
            return []
        }

        let rawEvent = buffer
        buffer.removeAll()
        return try parse(rawEvent)
    }

    private func parse(_ rawEvent: String) throws -> [AnthropicStreamEvent] {
        var eventType: String?
        var dataPayloads: [String] = []

        for line in rawEvent.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("event:") {
                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataPayloads.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }

        var events: [AnthropicStreamEvent] = []
        for payload in dataPayloads {
            if eventType == "message_stop" {
                events.append(.done)
                continue
            }

            let data = Data(payload.utf8)
            switch eventType {
            case "content_block_delta":
                let chunk = try decoder.decode(ContentBlockDeltaEvent.self, from: data)
                if chunk.delta.type == "text_delta", let text = chunk.delta.text, !text.isEmpty {
                    events.append(.textDelta(text))
                }
            case "message_delta":
                let chunk = try decoder.decode(MessageDeltaEvent.self, from: data)
                if let stopReason = chunk.delta.stopReason {
                    events.append(.finishReason(stopReason.llmFinishReason))
                }
                if let usage = chunk.usage {
                    events.append(.usage(LLMUsage(outputTokens: usage.outputTokens)))
                }
            case "message_start":
                let chunk = try decoder.decode(MessageStartEvent.self, from: data)
                events.append(
                    .usage(
                        LLMUsage(
                            inputTokens: chunk.message.usage?.inputTokens,
                            outputTokens: chunk.message.usage?.outputTokens
                        )
                    )
                )
            default:
                break
            }
        }

        return events
    }
}

private struct ContentBlockDeltaEvent: Decodable {
    var delta: Delta

    struct Delta: Decodable {
        var type: String
        var text: String?
    }
}

private struct MessageDeltaEvent: Decodable {
    var delta: Delta
    var usage: Usage?

    struct Delta: Decodable {
        var stopReason: AnthropicStopReason?

        enum CodingKeys: String, CodingKey {
            case stopReason = "stop_reason"
        }
    }
}

private struct MessageStartEvent: Decodable {
    var message: Message

    struct Message: Decodable {
        var usage: Usage?
    }
}

private struct Usage: Decodable {
    var inputTokens: Int?
    var outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

private enum AnthropicStopReason: String, Decodable {
    case endTurn = "end_turn"
    case maxTokens = "max_tokens"
    case stopSequence = "stop_sequence"
    case toolUse = "tool_use"

    var llmFinishReason: LLMFinishReason {
        switch self {
        case .endTurn, .stopSequence:
            .stop
        case .maxTokens:
            .length
        case .toolUse:
            .providerSpecific
        }
    }
}
