public struct LLMToken: Codable, Sendable, Equatable {
    public var text: String
    public var index: Int?
    public var isSpecial: Bool

    public init(
        text: String,
        index: Int? = nil,
        isSpecial: Bool = false
    ) {
        self.text = text
        self.index = index
        self.isSpecial = isSpecial
    }
}
