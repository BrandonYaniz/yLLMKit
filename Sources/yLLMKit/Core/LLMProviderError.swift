public enum LLMProviderError: Error, Codable, Hashable, Sendable {
    case modelNotFound(LLMModelID)
    case modelNotPrepared(LLMModelID)
    case unsupportedCapability(String)
    case invalidRequest(String)
    case authenticationFailed(String)
    case rateLimited(String)
    case transportFailed(String)
    case providerFailed(String)
    case cancelled
}
