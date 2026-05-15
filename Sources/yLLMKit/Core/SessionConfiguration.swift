public struct SessionConfiguration: Codable, Sendable, Equatable {
    public var systemPrompt: String?
    public var metadata: [String: String]

    public init(
        systemPrompt: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.systemPrompt = systemPrompt
        self.metadata = metadata
    }
}
