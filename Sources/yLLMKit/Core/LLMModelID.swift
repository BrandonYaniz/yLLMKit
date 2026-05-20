public struct LLMModelID: Codable, Hashable, Sendable, CustomStringConvertible {
    public var providerID: LLMProviderID
    public var modelName: String

    public var description: String {
        "\(providerID.rawValue):\(modelName)"
    }

    public init(providerID: LLMProviderID, modelName: String) {
        self.providerID = providerID
        self.modelName = modelName
    }
}
