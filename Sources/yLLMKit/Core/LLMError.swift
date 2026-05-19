public enum LLMError: Error, Codable, Sendable, Equatable {
    case invalidRequest(String)
    case modelNotFound(String)
    case modelNotInstalled(String)
    case modelNotLoaded(String)
    case unsupportedCapability(String)
    case generationCancelled
    case backendUnavailable(String)
    case backendFailure(String)
}
