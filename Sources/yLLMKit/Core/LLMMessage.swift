public struct LLMMessage: Codable, Sendable, Equatable {
    public enum Role: String, Codable, Sendable, Equatable {
        case system
        case user
        case assistant
        case tool
    }

    public var role: Role
    public var content: String
    public var metadata: [String: String]

    public init(
        role: Role,
        content: String,
        metadata: [String: String] = [:]
    ) {
        self.role = role
        self.content = content
        self.metadata = metadata
    }
}
