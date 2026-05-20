import Foundation

public struct LoadedModel: Sendable, Identifiable, Equatable {
    public var id: String { model.id }
    public var model: ModelDescriptor
    public var localModel: LocalModel?
    public var loadedAt: Date
    public var loadTimeSeconds: Double?

    public init(
        model: ModelDescriptor,
        localModel: LocalModel? = nil,
        loadedAt: Date = Date(),
        loadTimeSeconds: Double? = nil
    ) {
        self.model = model
        self.localModel = localModel
        self.loadedAt = loadedAt
        self.loadTimeSeconds = loadTimeSeconds
    }
}
