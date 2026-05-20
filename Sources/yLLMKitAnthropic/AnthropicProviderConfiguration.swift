import Foundation
import yLLMKit

public struct AnthropicProviderConfiguration: Sendable {
    public var apiKey: String
    public var baseURL: URL
    public var version: String
    public var models: [LLMModelDescriptor]

    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.anthropic.com")!,
        version: String = "2023-06-01",
        models: [LLMModelDescriptor] = []
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.version = version
        self.models = models
    }
}
