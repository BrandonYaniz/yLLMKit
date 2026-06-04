import Foundation
import yLLMKit

public final class OpenAIProvider: RemoteLLMProvider, @unchecked Sendable {
    public let providerID = LLMProviderID(rawValue: "openai")

    private let configuration: OpenAIProviderConfiguration
    private let transport: any OpenAITransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        configuration: OpenAIProviderConfiguration,
        transport: any OpenAITransport = URLSessionOpenAITransport()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
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
            throw LLMProviderError.authenticationFailed("OpenAI API key is empty.")
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

                    var parser = OpenAIServerSentEventParser()
                    var output = ""
                    var usage: LLMUsage?
                    var finishReason: LLMFinishReason?

                    for try await data in transport.stream(for: urlRequest) {
                        for event in try parser.append(data) {
                            switch event {
                            case .textDelta(let text):
                                output += text
                                continuation.yield(.textDelta(text))
                            case .usage(let value):
                                usage = value
                            case .finishReason(let value):
                                finishReason = value
                            case .done:
                                break
                            }
                        }
                    }

                    for event in try parser.finish() {
                        switch event {
                        case .textDelta(let text):
                            output += text
                            continuation.yield(.textDelta(text))
                        case .usage(let value):
                            usage = value
                        case .finishReason(let value):
                            finishReason = value
                        case .done:
                            break
                        }
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
                } catch let error as OpenAIHTTPError {
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
                .appendingPathComponent("chat")
                .appendingPathComponent("completions")
        )
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let organizationID = configuration.organizationID {
            urlRequest.setValue(organizationID, forHTTPHeaderField: "OpenAI-Organization")
        }
        if let projectID = configuration.projectID {
            urlRequest.setValue(projectID, forHTTPHeaderField: "OpenAI-Project")
        }

        urlRequest.httpBody = try encoder.encode(OpenAIChatCompletionRequest(request))
        return urlRequest
    }

    private static func providerError(for statusCode: Int) -> LLMProviderError {
        switch statusCode {
        case 401, 403:
            .authenticationFailed("OpenAI request failed with HTTP \(statusCode).")
        case 408, 429:
            .rateLimited("OpenAI request failed with HTTP \(statusCode).")
        case 400..<500:
            .invalidRequest("OpenAI request failed with HTTP \(statusCode).")
        default:
            .transportFailed("OpenAI request failed with HTTP \(statusCode).")
        }
    }
}
