public struct LLMProviderID: Codable, Hashable, Sendable, RawRepresentable, CustomStringConvertible {
    public var rawValue: String

    public var description: String {
        rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
