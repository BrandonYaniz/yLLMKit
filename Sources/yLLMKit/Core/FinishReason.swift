public enum FinishReason: String, Codable, Sendable, Equatable {
    case stop
    case length
    case cancelled
    case error
}
