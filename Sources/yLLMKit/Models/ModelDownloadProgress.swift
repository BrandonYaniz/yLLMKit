public struct ModelDownloadProgress: Codable, Sendable, Equatable {
    public enum Phase: String, Codable, Sendable, Equatable {
        case queued
        case downloading
        case verifying
        case installing
        case complete
    }

    public var modelID: String
    public var phase: Phase
    public var fractionCompleted: Double?
    public var completedBytes: Int64?
    public var totalBytes: Int64?
    public var message: String?
    public var localModel: LocalModel?

    public init(
        modelID: String,
        phase: Phase,
        fractionCompleted: Double? = nil,
        completedBytes: Int64? = nil,
        totalBytes: Int64? = nil,
        message: String? = nil,
        localModel: LocalModel? = nil
    ) {
        self.modelID = modelID
        self.phase = phase
        self.fractionCompleted = fractionCompleted
        self.completedBytes = completedBytes
        self.totalBytes = totalBytes
        self.message = message
        self.localModel = localModel
    }
}
