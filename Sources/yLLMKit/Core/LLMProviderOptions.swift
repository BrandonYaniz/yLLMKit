public struct LLMProviderOptions: Codable, Hashable, Sendable {
    public var values: [String: JSONValue]

    public static let empty = LLMProviderOptions()

    public init(values: [String: JSONValue] = [:]) {
        self.values = values
    }
}
