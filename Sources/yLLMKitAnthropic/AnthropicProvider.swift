import Foundation
import yLLMKit

public final class AnthropicProvider: RemoteLLMProvider, @unchecked Sendable {
    public let providerID = LLMProviderID(rawValue: "anthropic")

    private let configuration: AnthropicProviderConfiguration
    private let transport: any AnthropicTransport
    private let encoder = JSONEncoder()

    public init(
        configuration: AnthropicProviderConfiguration,
        transport: any AnthropicTransport = URLSessionAnthropicTransport()
    ) {
        self.configuration = configuration
        self.transport = transport
    }

    public func availableModels() async throws -> [LLMModelDescriptor] {
        configuration.models
    }

    public func prepareModel(_ modelID: LLMModelID) async throws {
        guard modelID.providerID == providerID else {
            throw LLMProviderError.modelNotFound(modelID)
        }
        try await validateConfiguration()
        if !configuration.models.isEmpty,
           !configuration.models.contains(where: { $0.id == modelID }) {
            throw LLMProviderError.modelNotFound(modelID)
        }
    }

    public func validateConfiguration() async throws {
        guard !configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMProviderError.authenticationFailed("Anthropic API key is empty.")
        }
    }

    public func streamChat(
        request: LLMChatRequest
    ) -> AsyncThrowingStream<LLMStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await prepareModel(request.modelID)
                    let urlRequest = try makeURLRequest(for: request)
                    continuation.yield(.started(LLMStreamStart(modelID: request.modelID)))

                    var parser = AnthropicServerSentEventParser()
                    var output = ""
                    var usage: LLMUsage?
                    var finishReason: LLMFinishReason?

                    for try await data in transport.stream(for: urlRequest) {
                        for event in try parser.append(data) {
                            apply(
                                event,
                                output: &output,
                                usage: &usage,
                                finishReason: &finishReason,
                                continuation: continuation
                            )
                        }
                    }

                    for event in try parser.finish() {
                        apply(
                            event,
                            output: &output,
                            usage: &usage,
                            finishReason: &finishReason,
                            continuation: continuation
                        )
                    }

                    continuation.yield(
                        .completed(
                            LLMChatResponse(
                                modelID: request.modelID,
                                message: LLMMessage(role: .assistant, content: output),
                                usage: usage,
                                finishReason: finishReason ?? .stop
                            )
                        )
                    )
                    continuation.finish()
                } catch let error as LLMProviderError {
                    continuation.finish(throwing: error)
                } catch let error as AnthropicHTTPError {
                    continuation.finish(throwing: Self.providerError(for: error.statusCode))
                } catch is CancellationError {
                    continuation.finish(throwing: LLMProviderError.cancelled)
                } catch {
                    continuation.finish(throwing: LLMProviderError.providerFailed(String(describing: error)))
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    internal func makeURLRequest(for request: LLMChatRequest) throws -> URLRequest {
        var urlRequest = URLRequest(
            url: configuration.baseURL
                .appendingPathComponent("v1")
                .appendingPathComponent("messages")
        )
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(configuration.version, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(AnthropicMessagesRequest(request))
        return urlRequest
    }

    private func apply(
        _ event: AnthropicStreamEvent,
        output: inout String,
        usage: inout LLMUsage?,
        finishReason: inout LLMFinishReason?,
        continuation: AsyncThrowingStream<LLMStreamEvent, Error>.Continuation
    ) {
        switch event {
        case .textDelta(let text):
            output += text
            continuation.yield(.textDelta(text))
        case .usage(let value):
            usage = usage.merging(value)
        case .finishReason(let value):
            finishReason = value
        case .done:
            break
        }
    }

    private static func providerError(for statusCode: Int) -> LLMProviderError {
        switch statusCode {
        case 401, 403:
            .authenticationFailed("Anthropic request failed with HTTP \(statusCode).")
        case 408, 429:
            .rateLimited("Anthropic request failed with HTTP \(statusCode).")
        case 400..<500:
            .invalidRequest("Anthropic request failed with HTTP \(statusCode).")
        default:
            .transportFailed("Anthropic request failed with HTTP \(statusCode).")
        }
    }
}

private extension Optional where Wrapped == LLMUsage {
    func merging(_ next: LLMUsage) -> LLMUsage {
        guard let current = self else {
            return next
        }

        let inputTokens = next.inputTokens ?? current.inputTokens
        let outputTokens = next.outputTokens ?? current.outputTokens
        let totalTokens = next.totalTokens ?? current.totalTokens ?? {
            guard let inputTokens, let outputTokens else {
                return nil
            }
            return inputTokens + outputTokens
        }()

        return LLMUsage(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens
        )
    }
}
