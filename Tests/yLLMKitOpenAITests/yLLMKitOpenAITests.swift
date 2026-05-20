#if canImport(XCTest)
import Foundation
import XCTest
import yLLMKit
@testable import yLLMKitOpenAI

final class yLLMKitOpenAITests: XCTestCase {
    func testOpenAIProviderBuildsChatCompletionRequest() throws {
        let model = openAIModel("gpt-test")
        let provider = OpenAIProvider(
            configuration: OpenAIProviderConfiguration(
                apiKey: "test-key",
                baseURL: URL(string: "https://example.test")!,
                organizationID: "org-test",
                projectID: "project-test",
                models: [model]
            ),
            transport: MockOpenAITransport(chunks: [])
        )
        let request = LLMChatRequest(
            modelID: model.id,
            messages: [
                LLMMessage(role: .system, content: "Be concise."),
                LLMMessage(role: .user, content: "Hello")
            ],
            settings: GenerationSettings(
                temperature: 0.2,
                topP: 0.9,
                maxOutputTokens: 64,
                stopSequences: ["STOP"]
            ),
            providerOptions: LLMProviderOptions(
                values: ["seed": .number(123)]
            )
        )

        let urlRequest = try provider.makeURLRequest(for: request)
        let body = try XCTUnwrap(urlRequest.httpBody)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let messages = try XCTUnwrap(object["messages"] as? [[String: Any]])
        let streamOptions = try XCTUnwrap(object["stream_options"] as? [String: Any])

        XCTAssertEqual(urlRequest.url?.absoluteString, "https://example.test/v1/chat/completions")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "OpenAI-Organization"), "org-test")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "OpenAI-Project"), "project-test")
        XCTAssertEqual(object["model"] as? String, "gpt-test")
        XCTAssertEqual(object["stream"] as? Bool, true)
        XCTAssertEqual(streamOptions["include_usage"] as? Bool, true)
        XCTAssertEqual(object["temperature"] as? Double, 0.2)
        XCTAssertEqual(object["top_p"] as? Double, 0.9)
        XCTAssertEqual(object["max_tokens"] as? Int, 64)
        XCTAssertEqual(object["stop"] as? [String], ["STOP"])
        XCTAssertEqual(object["seed"] as? Double, 123)
        XCTAssertEqual(messages.map { $0["role"] as? String }, ["system", "user"])
        XCTAssertEqual(messages.map { $0["content"] as? String }, ["Be concise.", "Hello"])
    }

    func testOpenAIProviderStreamsTextUsageAndCompletion() async throws {
        let model = openAIModel("gpt-test")
        let transport = MockOpenAITransport(
            chunks: [
                sse("""
                {"choices":[{"delta":{"content":"Hel"},"finish_reason":null}]}
                """),
                sse("""
                {"choices":[{"delta":{"content":"lo"},"finish_reason":"stop"}],"usage":{"prompt_tokens":3,"completion_tokens":2,"total_tokens":5}}
                """),
                Data("data: [DONE]\n\n".utf8)
            ]
        )
        let provider = OpenAIProvider(
            configuration: OpenAIProviderConfiguration(
                apiKey: "test-key",
                baseURL: URL(string: "https://example.test")!,
                models: [model]
            ),
            transport: transport
        )
        let request = LLMChatRequest(
            modelID: model.id,
            messages: [LLMMessage(role: .user, content: "Hello")]
        )

        var events: [LLMStreamEvent] = []
        for try await event in provider.streamChat(request: request) {
            events.append(event)
        }

        XCTAssertEqual(events.first, .started(LLMStreamStart(modelID: model.id)))
        XCTAssertEqual(events.dropFirst().first, .textDelta("Hel"))
        XCTAssertEqual(events.dropFirst(2).first, .textDelta("lo"))

        guard case .completed(let response) = events.last else {
            return XCTFail("Expected completed event.")
        }

        XCTAssertEqual(response.message.content, "Hello")
        XCTAssertEqual(response.usage?.inputTokens, 3)
        XCTAssertEqual(response.usage?.outputTokens, 2)
        XCTAssertEqual(response.usage?.totalTokens, 5)
        XCTAssertEqual(response.finishReason, .stop)

        let captured = transport.capturedRequests
        XCTAssertEqual(captured.count, 1)
    }

    func testOpenAIProviderMapsHTTPRateLimit() async throws {
        let model = openAIModel("gpt-test")
        let provider = OpenAIProvider(
            configuration: OpenAIProviderConfiguration(
                apiKey: "test-key",
                models: [model]
            ),
            transport: MockOpenAITransport(error: OpenAIHTTPError(statusCode: 429))
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

    func testOpenAIProviderRejectsEmptyAPIKeyDuringPreparation() async throws {
        let model = openAIModel("gpt-test")
        let provider = OpenAIProvider(
            configuration: OpenAIProviderConfiguration(apiKey: "", models: [model]),
            transport: MockOpenAITransport(chunks: [])
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

    private func openAIModel(_ modelName: String) -> LLMModelDescriptor {
        LLMModelDescriptor(
            id: LLMModelID(
                providerID: LLMProviderID(rawValue: "openai"),
                modelName: modelName
            ),
            displayName: "GPT Test",
            capabilities: LLMModelCapabilities(
                supportsStreaming: true,
                supportsLocalPreparation: false,
                contextWindow: 128_000,
                maxOutputTokens: 16_384
            ),
            defaultSettings: .balanced,
            providerMetadata: ["vendor": .string("openai")]
        )
    }

    private func sse(_ json: String) -> Data {
        Data("data: \(json.trimmingCharacters(in: .whitespacesAndNewlines))\n\n".utf8)
    }
}

private final class MockOpenAITransport: OpenAITransport, @unchecked Sendable {
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
