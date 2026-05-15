import Foundation

public actor ModelRegistry {
    private var modelsByID: [String: ModelDescriptor]

    public init(models: [ModelDescriptor]) throws {
        var modelsByID: [String: ModelDescriptor] = [:]

        for model in models {
            guard modelsByID[model.id] == nil else {
                throw LLMError.invalidRequest("Duplicate model id: \(model.id)")
            }
            modelsByID[model.id] = model
        }

        self.modelsByID = modelsByID
    }

    public init(manifests: [ModelManifest]) throws {
        try self.init(models: manifests.flatMap(\.models))
    }

    public init(manifestData: Data, decoder: JSONDecoder = JSONDecoder()) throws {
        let manifest = try decoder.decode(ModelManifest.self, from: manifestData)
        try self.init(manifests: [manifest])
    }

    public init(manifestDataList: [Data], decoder: JSONDecoder = JSONDecoder()) throws {
        let manifests = try manifestDataList.map { data in
            try decoder.decode(ModelManifest.self, from: data)
        }
        try self.init(manifests: manifests)
    }

    public func supportedModels() -> [ModelDescriptor] {
        modelsByID.values.sorted { $0.displayName < $1.displayName }
    }

    public func model(id: String) throws -> ModelDescriptor {
        guard let model = modelsByID[id] else {
            throw LLMError.modelNotFound(id)
        }
        return model
    }

    public func models(forBackend backendID: String) -> [ModelDescriptor] {
        modelsByID.values
            .filter { $0.backendID == backendID }
            .sorted { $0.displayName < $1.displayName }
    }
}
