# yLLMKit API Shape

This document describes the target v1 API shape.

v1 is text/chat only.

## Provider

```swift
public protocol LLMProvider: Sendable {
    var providerID: LLMProviderID { get }

    func availableModels() async throws -> [LLMModelDescriptor]

    func prepareModel(
        _ modelID: LLMModelID
    ) async throws

    func streamChat(
        request: LLMChatRequest
    ) -> AsyncThrowingStream<LLMStreamEvent, Error>
}
```

`prepareModel` means "make this model ready enough for a chat request."

For local providers, preparation may validate install state, download, load, or warm a model depending on provider policy. For remote providers, preparation may validate configuration or be a no-op.

If local lifecycle behavior needs richer progress, keep that behavior in the local provider product or a local-model protocol refinement rather than adding MLX-specific lifecycle requirements to core.

## Local Provider

yLLMKit is local-first. Local providers should share the same chat interface as remote providers, but they also need explicit lifecycle controls that hosted providers do not have.

```swift
public protocol LocalLLMProvider: LLMProvider {
    func localModels() async throws -> [LocalModel]
    func isModelPrepared(_ modelID: LLMModelID) async throws -> Bool

    func prepareModelWithProgress(
        _ modelID: LLMModelID
    ) -> AsyncThrowingStream<ModelDownloadProgress, Error>

    func unloadModel(_ modelID: LLMModelID) async throws
    func removeModel(_ modelID: LLMModelID) async throws
}
```

`LLMProvider.prepareModel(_:)` remains the simple cross-provider preparation call.

`LocalLLMProvider.prepareModelWithProgress(_:)` is the local-first path for apps that need to show download, install, load, or warmup progress.

`unloadModel(_:)` should release loaded runtime resources where the provider supports that.

`removeModel(_:)` should remove provider-owned local model state where practical. Providers should document whether this removes on-disk files, in-memory loaded state, package-managed metadata, or some combination of those.

Hosted providers such as OpenAI and Anthropic should not be forced to implement local lifecycle concepts.

## Remote Provider

Remote providers share the base chat interface and may expose hosted-configuration validation without adopting local lifecycle behavior.

```swift
public protocol RemoteLLMProvider: LLMProvider {
    func validateConfiguration() async throws
}
```

`validateConfiguration()` should catch missing or malformed hosted-provider configuration that can be checked without performing a live model request. API keys should still come from the consuming app's secure runtime configuration, not source-controlled examples.

Hosted provider products are courtesy integrations. They should remain familiar to use beside local providers, but they should not add remote-only concepts to local provider requirements.

## Model IDs

```swift
public struct LLMProviderID: Codable, Hashable, Sendable, RawRepresentable {
    public var rawValue: String

    public init(rawValue: String)
}

public struct LLMModelID: Codable, Hashable, Sendable {
    public var providerID: LLMProviderID
    public var modelName: String

    public init(providerID: LLMProviderID, modelName: String)
}
```

`LLMProviderID` should encode as its raw string value.

`LLMModelID` values should be displayed as provider-scoped identifiers such as `mlx:phi-3.5-mini`, `openai:gpt-...`, or `anthropic:claude-...`.

## Model Descriptor

```swift
public struct LLMModelDescriptor: Codable, Hashable, Sendable, Identifiable {
    public var id: LLMModelID
    public var displayName: String
    public var capabilities: LLMModelCapabilities
    public var defaultSettings: GenerationSettings?
    public var providerMetadata: [String: JSONValue]
}
```

`providerMetadata` is for provider-owned catalog data such as repository names, revisions, recommended memory, or vendor labels. Core should preserve it but avoid interpreting provider-specific keys.

## Capabilities

```swift
public struct LLMModelCapabilities: Codable, Hashable, Sendable {
    public var supportsStreaming: Bool
    public var supportsLocalPreparation: Bool
    public var contextWindow: Int?
    public var maxOutputTokens: Int?
}
```

Do not add vision, tool, embedding, or multimodal capabilities in v1.

## Message

```swift
public struct LLMMessage: Codable, Hashable, Sendable {
    public var role: LLMRole
    public var content: String
    public var metadata: [String: String]

    public init(role: LLMRole, content: String, metadata: [String: String] = [:])
}
```

```swift
public enum LLMRole: String, Codable, Hashable, Sendable {
    case system
    case user
    case assistant
}
```

No tool role in v1.

## Chat Request

```swift
public struct LLMChatRequest: Sendable {
    public var modelID: LLMModelID
    public var messages: [LLMMessage]
    public var settings: GenerationSettings
    public var providerOptions: LLMProviderOptions

    public init(
        modelID: LLMModelID,
        messages: [LLMMessage],
        settings: GenerationSettings = .balanced,
        providerOptions: LLMProviderOptions = .empty
    )
}
```

## Chat Response

```swift
public struct LLMChatResponse: Sendable {
    public var modelID: LLMModelID
    public var message: LLMMessage
    public var usage: LLMUsage?
    public var finishReason: LLMFinishReason?
    public var providerMetadata: [String: String]
}
```

## Stream Events

```swift
public enum LLMStreamEvent: Sendable {
    case started(LLMStreamStart)
    case textDelta(String)
    case completed(LLMChatResponse)
}
```

Use stream failure for errors.

```swift
public struct LLMStreamStart: Codable, Hashable, Sendable {
    public var modelID: LLMModelID
    public var providerMetadata: [String: String]
}
```

```swift
public enum LLMFinishReason: String, Codable, Hashable, Sendable {
    case stop
    case length
    case cancelled
    case providerSpecific
}
```

## Generation Settings

```swift
public struct GenerationSettings: Codable, Hashable, Sendable {
    public var temperature: Double?
    public var topP: Double?
    public var maxOutputTokens: Int?
    public var stopSequences: [String]

    public static let balanced: GenerationSettings
    public static let precise: GenerationSettings
}
```

Keep provider-specific settings out of the common type unless they are broadly supported.

## Provider Options

```swift
public struct LLMProviderOptions: Codable, Hashable, Sendable {
    public var values: [String: JSONValue]

    public static let empty: LLMProviderOptions

    public init(values: [String: JSONValue] = [:])
}
```

This is the escape hatch for provider-specific options.

```swift
public enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null
}
```

## Usage

```swift
public struct LLMUsage: Codable, Hashable, Sendable {
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var totalTokens: Int?
}
```

Token usage is optional because providers report usage differently.

## Error Shape

```swift
public enum LLMProviderError: Error, Sendable {
    case modelNotFound(LLMModelID)
    case modelNotPrepared(LLMModelID)
    case unsupportedCapability(String)
    case invalidRequest(String)
    case authenticationFailed(String)
    case rateLimited(String)
    case transportFailed(String)
    case providerFailed(String)
    case cancelled
}
```

## Compatibility with Existing Runtime Types

Existing `LLMRuntime`, `LLMBackend`, and `LLMSession` concepts may remain temporarily while migration is underway.

The cross-provider public direction should move toward provider-neutral request/stream APIs.

Do not break working MLX behavior without replacing it with tested provider-equivalent behavior.

Runtime and manifest types such as `LLMRuntime`, `LLMBackend`, `LLMSession`, and `ModelDescriptor` are local-runtime compatibility APIs during beta. They should not be removed until the local provider refinement and provider-specific local lifecycle APIs preserve their useful local-first behavior, including download progress, installed model discovery, explicit loading, unloading, removal, and local catalog metadata.
