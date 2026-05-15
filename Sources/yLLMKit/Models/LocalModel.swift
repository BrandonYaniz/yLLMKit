import Foundation

public struct LocalModel: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var modelID: String
    public var backendID: String
    public var path: String
    public var installedAt: Date
    public var sizeBytes: Int64?

    public init(
        id: String,
        modelID: String,
        backendID: String,
        path: String,
        installedAt: Date,
        sizeBytes: Int64? = nil
    ) {
        self.id = id
        self.modelID = modelID
        self.backendID = backendID
        self.path = path
        self.installedAt = installedAt
        self.sizeBytes = sizeBytes
    }
}
