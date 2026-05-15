public struct ModelManifest: Codable, Sendable, Equatable {
    public var models: [ModelDescriptor]

    public init(models: [ModelDescriptor]) {
        self.models = models
    }

    public init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: CodingKeys.self),
           keyed.contains(.models) {
            self.models = try keyed.decode([ModelDescriptor].self, forKey: .models)
            return
        }

        let model = try ModelDescriptor(from: decoder)
        self.models = [model]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(models, forKey: .models)
    }

    private enum CodingKeys: String, CodingKey {
        case models
    }
}
