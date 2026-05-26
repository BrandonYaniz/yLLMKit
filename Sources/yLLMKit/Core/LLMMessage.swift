public typealias LLMRole = LLMMessage.Role

public struct LLMMessage: Codable, Sendable, Hashable {
    public enum Role: String, Codable, Sendable, Hashable {
        case system
        case user
        case assistant
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
