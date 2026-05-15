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
    public var completedBytes: Int64
    public var totalBytes: Int64?
    public var message: String?

    public init(
        modelID: String,
        phase: Phase,
        completedBytes: Int64 = 0,
        totalBytes: Int64? = nil,
        message: String? = nil
    ) {
        self.modelID = modelID
        self.phase = phase
        self.completedBytes = completedBytes
        self.totalBytes = totalBytes
        self.message = message
    }
}
