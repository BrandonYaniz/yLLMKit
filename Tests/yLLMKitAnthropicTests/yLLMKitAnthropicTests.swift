#if canImport(XCTest)
import Foundation
import XCTest
import yLLMKit
@testable import yLLMKitAnthropic

final class yLLMKitAnthropicTests: XCTestCase {
    func testAnthropicProviderBuildsMessagesRequest() throws {
        let model = anthropicModel("claude-test")
        let provider = AnthropicProvider(
            configuration: AnthropicProviderConfiguration(
                apiKey: "test-key",
                baseURL: URL(string: "https://example.test")!,
                version: "2023-06-01",
                models: [model]
            ),
            transport: MockAnthropicTransport(chunks: [])
        )
        let request = LLMChatRequest(
            modelID: model.id,
            messages: [
                LLMMessage(role: .system, content: "Be concise."),
                LLMMessage(role: .user, content: "Hello"),
                LLMMessage(role: .assistant, content: "Hi"),
                LLMMessage(role: .user, content: "Continue")
            ],
            settings: GenerationSettings(
                temperature: 0.2,
                topP: 0.9,
                maxOutputTokens: 64,
                stopSequences: ["STOP"]
            ),
            providerOptions: LLMProviderOptions(
                values: ["metadata": .object(["test": .bool(true)])]
            )
        )

        let urlRequest = try provider.makeURLRequest(for: request)
        let body = try XCTUnwrap(urlRequest.httpBody)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let messages = try XCTUnwrap(object["messages"] as? [[String: Any]])
        let metadata = try XCTUnwrap(object["metadata"] as? [String: Any])

        XCTAssertEqual(urlRequest.url?.absoluteString, "https://example.test/v1/messages")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "x-api-key"), "test-key")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(object["model"] as? String, "claude-test")
        XCTAssertEqual(object["system"] as? String, "Be concise.")
        XCTAssertEqual(object["stream"] as? Bool, true)
        XCTAssertEqual(object["max_tokens"] as? Int, 64)
        XCTAssertEqual(object["temperature"] as? Double, 0.2)
        XCTAssertEqual(object["top_p"] as? Double, 0.9)
        XCTAssertEqual(object["stop_sequences"] as? [String], ["STOP"])
        XCTAssertEqual(metadata["test"] as? Bool, true)
        XCTAssertEqual(messages.map { $0["role"] as? String }, ["user", "assistant", "user"])
        XCTAssertEqual(messages.map { $0["content"] as? String }, ["Hello", "Hi", "Continue"])
    }

    func testAnthropicProviderStreamsTextUsageAndCompletion() async throws {
        let model = anthropicModel("claude-test")
        let transport = MockAnthropicTransport(
            chunks: [
                sse(
                    event: "message_start",
                    json: #"{"message":{"usage":{"input_tokens":4,"output_tokens":0}}}"#
                ),
                sse(
                    event: "content_block_delta",
                    json: #"{"delta":{"type":"text_delta","text":"Hel"}}"#
                ),
                sse(
                    event: "content_block_delta",
                    json: #"{"delta":{"type":"text_delta","text":"lo"}}"#
                ),
                sse(
                    event: "message_delta",
                    json: #"{"delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":2}}"#
                ),
                sse(event: "message_stop", json: #"{}"#)
            ]
        )
        let provider = AnthropicProvider(
            configuration: AnthropicProviderConfiguration(
                apiKey: "test-key",
                baseURL: URL(string: "https://example.test")!,
                models: [model]
            ),
            transport: transport
        )

        var events: [LLMStreamEvent] = []
        for try await event in provider.streamChat(
            request: LLMChatRequest(
                modelID: model.id,
                messages: [LLMMessage(role: .user, content: "Hello")]
            )
        ) {
            events.append(event)
        }

        XCTAssertEqual(events.first, .started(LLMStreamStart(modelID: model.id)))
        XCTAssertEqual(events.dropFirst().first, .textDelta("Hel"))
        XCTAssertEqual(events.dropFirst(2).first, .textDelta("lo"))

        guard case .completed(let response) = events.last else {
            return XCTFail("Expected completed event.")
        }

        XCTAssertEqual(response.message.content, "Hello")
        XCTAssertEqual(response.usage?.outputTokens, 2)
        XCTAssertEqual(response.finishReason, .stop)
        XCTAssertEqual(transport.capturedRequests.count, 1)
    }

    func testAnthropicProviderMapsHTTPRateLimit() async throws {
        let model = anthropicModel("claude-test")
        let provider = AnthropicProvider(
            configuration: AnthropicProviderConfiguration(
                apiKey: "test-key",
                models: [model]
            ),
            transport: MockAnthropicTransport(error: AnthropicHTTPError(statusCode: 429))
        )

        do {
            for try await _ in provider.streamChat(
                request: LLMChatRequest(
                    modelID: model.id,
                    messages: [LLMMessage(role: .user, content: "Hello")]
                )
            ) {}
            XCTFail("Expected stream to fail.")
        } catch LLMProviderError.rateLimited(let message) {
            XCTAssertTrue(message.contains("429"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAnthropicProviderRejectsEmptyAPIKeyDuringPreparation() async throws {
        let model = anthropicModel("claude-test")
        let provider = AnthropicProvider(
            configuration: AnthropicProviderConfiguration(apiKey: "", models: [model]),
            transport: MockAnthropicTransport(chunks: [])
        )

        do {
            try await provider.prepareModel(model.id)
            XCTFail("Expected authentication failure.")
        } catch LLMProviderError.authenticationFailed {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func anthropicModel(_ modelName: String) -> LLMModelDescriptor {
        LLMModelDescriptor(
            id: LLMModelID(
                providerID: LLMProviderID(rawValue: "anthropic"),
                modelName: modelName
            ),
            displayName: "Claude Test",
            capabilities: LLMModelCapabilities(
                supportsStreaming: true,
                supportsLocalPreparation: false,
                contextWindow: 200_000,
                maxOutputTokens: 8192
            ),
            defaultSettings: .balanced,
            providerMetadata: ["vendor": .string("anthropic")]
        )
    }

    private func sse(event: String, json: String) -> Data {
        Data("event: \(event)\ndata: \(json)\n\n".utf8)
    }
}

private final class MockAnthropicTransport: AnthropicTransport, @unchecked Sendable {
    private let chunks: [Data]
    private let error: Error?
    private let lock = NSLock()
    private var requests: [URLRequest] = []

    var capturedRequests: [URLRequest] {
        lock.withLock {
            requests
        }
    }

    init(chunks: [Data] = [], error: Error? = nil) {
        self.chunks = chunks
        self.error = error
    }

    func stream(for request: URLRequest) -> AsyncThrowingStream<Data, Error> {
        lock.withLock {
            requests.append(request)
        }
        let chunks = chunks
        let error = error

        return AsyncThrowingStream { continuation in
            if let error {
                continuation.finish(throwing: error)
                return
            }

            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }
}
#endif
