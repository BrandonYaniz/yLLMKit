public protocol LocalLLMProvider: LLMProvider {
    func localModels() async throws -> [LocalModel]
    func isModelPrepared(_ modelID: LLMModelID) async throws -> Bool

    func prepareModelWithProgress(
        _ modelID: LLMModelID
    ) -> AsyncThrowingStream<ModelDownloadProgress, Error>

    func unloadModel(_ modelID: LLMModelID) async throws
    func removeModel(_ modelID: LLMModelID) async throws
}
