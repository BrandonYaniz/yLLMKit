import Foundation
import yLLMKit

public struct OpenAIProviderConfiguration: Sendable {
    public var apiKey: String
    public var baseURL: URL
    public var organizationID: String?
    public var projectID: String?
    public var models: [LLMModelDescriptor]

    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.openai.com")!,
        organizationID: String? = nil,
        projectID: String? = nil,
        models: [LLMModelDescriptor] = []
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.organizationID = organizationID
        self.projectID = projectID
        self.models = models
    }
}
