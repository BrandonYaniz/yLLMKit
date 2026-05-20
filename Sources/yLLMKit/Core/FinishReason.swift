public typealias LLMFinishReason = FinishReason

public enum FinishReason: String, Codable, Sendable, Hashable {
    case stop
    case length
    case cancelled
    case error
    case providerSpecific
}
