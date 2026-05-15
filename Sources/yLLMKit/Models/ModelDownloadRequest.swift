public struct ModelDownloadRequest: Codable, Sendable, Equatable {
    public var model: ModelDescriptor
    public var destinationPath: String?
    public var allowsCellularAccess: Bool

    public init(
        model: ModelDescriptor,
        destinationPath: String? = nil,
        allowsCellularAccess: Bool = false
    ) {
        self.model = model
        self.destinationPath = destinationPath
        self.allowsCellularAccess = allowsCellularAccess
    }
}
