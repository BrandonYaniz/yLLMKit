public protocol RemoteLLMProvider: LLMProvider {
    func validateConfiguration() async throws
}
