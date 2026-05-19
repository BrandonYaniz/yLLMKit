# yLLMKit API Shape

## LLMBackend

```swift
public protocol LLMBackend: Sendable {
    var id: String { get }
    var name: String { get }

    func availableModels() async throws -> [ModelDescriptor]
    func localModels() async throws -> [LocalModel]
    func downloadModel(_ model: ModelDescriptor) -> AsyncThrowingStream<ModelDownloadProgress, Error>
    func loadModel(_ model: ModelDescriptor) async throws -> LoadedModel
    func unloadModel(_ modelID: String) async throws
    func createSession(modelID: String, configuration: SessionConfiguration) async throws -> any LLMSession
}
```

## LLMSession

```swift
public protocol LLMSession: Sendable {
    var id: UUID { get }
    var model: ModelDescriptor { get }

    func respond(
        to messages: [LLMMessage],
        settings: GenerationSettings
    ) async throws -> LLMResponse

    func streamResponse(
        to messages: [LLMMessage],
        settings: GenerationSettings
    ) -> AsyncThrowingStream<LLMToken, Error>

    func cancel()
}
```

## LLMMessage

```swift
public struct LLMMessage: Codable, Sendable, Equatable {
    public enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    public var role: Role
    public var content: String
    public var metadata: [String: String]
}
```

## GenerationSettings

```swift
public struct GenerationSettings: Codable, Sendable, Equatable {
    public var temperature: Double
    public var topP: Double
    public var maxTokens: Int?
    public var repetitionPenalty: Double?
    public var stopSequences: [String]

    public static let balanced = GenerationSettings(
        temperature: 0.7,
        topP: 0.9,
        maxTokens: nil,
        repetitionPenalty: nil,
        stopSequences: []
    )

    public static let precise = GenerationSettings(
        temperature: 0.2,
        topP: 0.8,
        maxTokens: nil,
        repetitionPenalty: nil,
        stopSequences: []
    )
}
```

## ModelDescriptor

```swift
public struct ModelDescriptor: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var displayName: String
    public var backendID: String
    public var provider: String
    public var repository: String
    public var revision: String?
    public var capabilities: ModelCapabilities
    public var recommendedRAMGB: Int?
    public var defaultSettings: GenerationSettings
}
```

## ModelDownloadProgress

```swift
public struct ModelDownloadProgress: Codable, Sendable, Equatable {
    public var modelID: String
    public var phase: Phase
    public var fractionCompleted: Double?
    public var completedBytes: Int64?
    public var totalBytes: Int64?
    public var message: String?
    public var localModel: LocalModel?
}
```

Use `fractionCompleted` for percent UI. `completedBytes` and `totalBytes` are optional because some backends report file counts or synthetic work units instead of bytes.

## ModelCapabilities

```swift
public struct ModelCapabilities: Codable, Sendable, Equatable {
    public var supportsChat: Bool
    public var supportsCompletion: Bool
    public var supportsVision: Bool
    public var supportsEmbeddings: Bool
    public var supportsToolCalling: Bool
    public var supportsJSONMode: Bool
    public var contextWindow: Int
    public var preferredMaxOutputTokens: Int?
}
```

## Runtime Usage Goal

```swift
let runtime = LLMRuntime(backends: [MLXBackend()])

let model = try await runtime.modelRegistry.model(id: "fast-local-assistant")
try await runtime.loadModel(model)

let session = try await runtime.createSession(
    modelID: model.id,
    configuration: SessionConfiguration(systemPrompt: "Use supplied source data carefully.")
)

let messages: [LLMMessage] = [
    .init(role: .user, content: "Summarize this context.", metadata: [:])
]

for try await token in session.streamResponse(to: messages, settings: .balanced) {
    print(token.text, terminator: "")
}
```
