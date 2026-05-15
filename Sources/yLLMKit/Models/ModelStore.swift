public protocol ModelStore: Sendable {
    func localModels() async throws -> [LocalModel]
    func localModel(for modelID: String) async throws -> LocalModel?
    func isModelInstalled(_ modelID: String) async throws -> Bool
    func register(_ model: LocalModel) async throws
    func removeModel(id modelID: String) async throws
}
