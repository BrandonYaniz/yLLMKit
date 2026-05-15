public protocol LLMBackend: Sendable {
    var id: String { get }
    var name: String { get }

    func availableModels() async throws -> [ModelDescriptor]
    func localModels() async throws -> [LocalModel]
    func downloadModel(_ request: ModelDownloadRequest) async -> AsyncThrowingStream<ModelDownloadProgress, Error>
    func loadModel(_ model: ModelDescriptor, from localModel: LocalModel?) async throws -> LoadedModel
    func unloadModel(_ modelID: String) async throws
    func createSession(
        model: LoadedModel,
        configuration: SessionConfiguration
    ) async throws -> any LLMSession
}
