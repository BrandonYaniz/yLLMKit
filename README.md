# yLLMKit

`yLLMKit` is a local-first Swift package for building text/chat LLM features with a small provider-neutral core and optional provider products.

The package gives Swift developers one shared chat interface for local and remote language models without forcing every app target to carry every provider dependency. Local Apple Silicon inference through MLX is the primary path. Hosted providers such as OpenAI or Anthropic are included as courtesy integrations so apps can use one familiar package when remote models make sense. Apps can start with the lightweight core types, add MLX for local inference, add hosted providers selectively, and use the context layer when prompts need structured source material instead of ad hoc string assembly.

This shape keeps product code flexible as model strategy changes. A SwiftUI app, AppKit app, command line tool, or service layer can build around the same request, response, streaming, settings, usage, and error types while still leaving provider-specific behavior in the product that owns it. That makes it easier to prototype with a mock backend, ship a local-first experience, fall back to remote models, or swap providers without rewriting the application layer that prepares conversations and consumes streamed output.

## Status

This project is pre-beta.

The repository currently contains this product shape:

```text
yLLMKit
yLLMKitMLX
yLLMKitOpenAI
yLLMKitAnthropic
yLLMKitContext
```

The v1 scope is text/chat only. Vision, audio, images, tool calling, function calling, embeddings, agents, realtime APIs, file uploads, workflow orchestration, and UI components are out of scope for v1.

The beta contract is local-first: local model lifecycle, preparation progress, cache behavior, unloading, and removal must remain first-class. Remote provider products should share the common chat shape without constraining local functionality.

## Design Goals

- Keep `yLLMKit` core small, UI-neutral, and provider-neutral.
- Put MLX, OpenAI, Anthropic, GRDB, and other concrete dependencies in optional products.
- Keep local model lifecycle first-class instead of reducing it to hosted-provider behavior.
- Use provider-scoped model identifiers instead of global naked model names.
- Stream text responses through Swift concurrency primitives.
- Preserve app ownership of source-of-truth data.
- Let apps choose local, remote, or deterministic-only context preparation.

## Products

### yLLMKit

Core shared types and protocols for provider-neutral text/chat:

- Provider identifiers and model identifiers.
- Model descriptors and capabilities.
- Chat messages, requests, responses, and stream events.
- Generation settings.
- Usage metadata.
- Normalized provider errors.
- Provider-specific options escape hatch.

The core product is the stable integration point for application code. It lets developers model conversations, generation settings, model identifiers, streaming events, usage, and provider errors once, then route requests to whichever provider product fits the current feature. Because it stays UI-neutral and provider-neutral, the same core layer can sit behind SwiftUI, AppKit, command line, or service code without pulling MLX, HTTP provider clients, GRDB, or other concrete dependencies into targets that do not need them.

### yLLMKitMLX

Local Apple Silicon inference through MLX. This product owns local model catalog, download, preparation, loading, streaming, cancellation, and MLX-specific mapping.

`yLLMKitMLX` brings local inference into the same chat shape as the rest of the package. Developers can offer offline or privacy-sensitive text generation, manage supported local models, surface preparation and streaming behavior, and cancel work without designing a separate app architecture for on-device models. Keeping MLX-specific catalog, download, loading, and prompt mapping here also means apps can add local Apple Silicon support without making the core package depend on MLX.

### yLLMKitOpenAI

Optional OpenAI text/chat provider. This courtesy integration owns OpenAI request mapping, streaming mapping, usage mapping, configuration, and error normalization.

`yLLMKitOpenAI` lets developers use OpenAI models through the same provider-neutral request and stream interface they use elsewhere in the package. The app can keep its chat orchestration, cancellation handling, settings, and response rendering consistent while the provider product handles OpenAI-specific transport details, event parsing, usage reporting, and error normalization. That separation makes it practical to support hosted models without scattering provider-specific JSON and networking concerns throughout the app.

### yLLMKitAnthropic

Optional Anthropic text/chat provider. This courtesy integration owns Anthropic request mapping, streaming mapping, usage mapping, configuration, and error normalization.

`yLLMKitAnthropic` gives developers access to Anthropic text/chat models without changing the application-facing chat model. Provider-specific request formats, server-sent events, usage metadata, configuration, and error mapping stay inside the Anthropic product, while app code continues to work with shared `LLMChatRequest`, `LLMStreamEvent`, and response types. This is useful for apps that want to compare providers, offer provider choice, or keep a remote fallback available beside local inference.

### yLLMKitContext

Optional context layer for conversation transcripts, app-supplied text sources, token-aware chunking, hierarchical summaries, source references, prompt budgeting, and GRDB-backed persistence.

`yLLMKitContext` helps developers turn app-owned text into prompt-ready context without giving up control of the source of truth. It can store transcripts and source records, split long material into useful chunks, maintain summaries, preserve source references, and build context packages that fit a prompt budget. That gives apps a reusable foundation for document-aware or memory-aware chat features while still letting the app decide what data is authoritative and how model suggestions become user-reviewed changes.

## Demo

A Swift project demonstrating this library is available at [BrandonYaniz/yLLMKit-Demo](https://github.com/BrandonYaniz/yLLMKit-Demo).

The package also includes a minimal local-first demo CLI:

```sh
swift run yLLMKitDemoCLI list-mlx-models
swift run yLLMKitDemoCLI prepare-mlx phi-2
swift run yLLMKitDemoCLI chat-mlx phi-2 "Reply with the word ready."
```

Hosted provider commands are available as courtesy integration checks and require runtime credentials:

```sh
OPENAI_API_KEY=... swift run yLLMKitDemoCLI chat-openai gpt-test "Say hello."
ANTHROPIC_API_KEY=... swift run yLLMKitDemoCLI chat-anthropic claude-test "Say hello."
```

## Requirements

- Swift 6.2 or later.
- macOS 14 or later.
- Apple Silicon is recommended for local MLX inference.
- Full Xcode is required for live MLX smoke tests because MLX needs the Metal compiler.

The core package is UI-neutral. You can use it from SwiftUI, AppKit, command line tools, server-side Swift where dependencies allow, or other Swift application layers.

## Installation

Add `yLLMKit` to your Swift package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/BrandonYaniz/yLLMKit.git", branch: "main")
]
```

Then add the core product to your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "yLLMKit", package: "yLLMKit")
    ]
)
```

For local MLX inference, add the MLX product as well:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "yLLMKit", package: "yLLMKit"),
        .product(name: "yLLMKitMLX", package: "yLLMKit")
    ]
)
```

Add only the provider products your target actually needs:

```swift
.product(name: "yLLMKitMLX", package: "yLLMKit")
.product(name: "yLLMKitOpenAI", package: "yLLMKit")
.product(name: "yLLMKitAnthropic", package: "yLLMKit")
.product(name: "yLLMKitContext", package: "yLLMKit")
```

Keeping provider products opt-in keeps simple targets small. A target that only models requests can depend on `yLLMKit`; a target that runs local inference can add `yLLMKitMLX`; a target that prepares context can add `yLLMKitContext`; and a target that talks to hosted models can add the remote provider product it uses.

## Quick Start

Build a chat request with provider-scoped model identifiers, then pass it to any product that conforms to `LLMProvider`:

```swift
import yLLMKit

let request = LLMChatRequest(
    modelID: LLMModelID(providerID: .init(rawValue: "mlx"), modelName: "phi-3.5-mini"),
    messages: [
        LLMMessage(role: .system, content: "Answer clearly and concisely."),
        LLMMessage(role: .user, content: "Summarize this note in three bullets.")
    ],
    settings: .balanced,
    providerOptions: .empty
)
```

Create the provider in the product that owns the concrete model backend:

```swift
import yLLMKit
import yLLMKitMLX

let provider: any LLMProvider = MLXProvider()
```

For hosted models, configure the matching remote provider product and keep API keys in your app's own secure configuration:

```swift
import yLLMKit
import yLLMKitOpenAI

let provider: any LLMProvider = OpenAIProvider(
    configuration: OpenAIProviderConfiguration(apiKey: openAIAPIKey)
)
```

```swift
import yLLMKit
import yLLMKitAnthropic

let provider: any LLMProvider = AnthropicProvider(
    configuration: AnthropicProviderConfiguration(apiKey: anthropicAPIKey)
)
```

Provider products stream `LLMStreamEvent` values through Swift concurrency:

```swift
try await provider.prepareModel(request.modelID)

for try await event in provider.streamChat(request: request) {
    switch event {
    case .started:
        break
    case .textDelta(let text):
        print(text, terminator: "")
    case .completed(let response):
        print("\nFinished:", response.finishReason ?? .stop)
    }
}
```

The app owns where messages come from and where responses go. `yLLMKit` provides the shared chat shape, provider products handle model-specific execution, and `yLLMKitContext` can help turn app-owned source material into prompt-ready messages when the conversation needs more than the latest user input.

## Local Lifecycle

Local providers expose lifecycle controls that hosted providers do not need:

```swift
let localProvider: any LocalLLMProvider = MLXProvider()

let modelID = LLMModelID(
    providerID: LLMProviderID(rawValue: "mlx"),
    modelName: "phi-2"
)

for try await progress in localProvider.prepareModelWithProgress(modelID) {
    print(progress.phase, progress.fractionCompleted ?? 0)
}

let isReady = try await localProvider.isModelPrepared(modelID)
```

Apps that already use `LLMRuntime`, `ModelRegistry`, `ModelStore`, and `LLMBackend` can adopt the provider-first API without replacing the runtime immediately:

```swift
let provider: any LocalLLMProvider = RuntimeLocalLLMProvider(
    providerID: LLMProviderID(rawValue: "local"),
    runtime: runtime,
    backendID: "mlx"
)
```

`RuntimeLocalLLMProvider` preserves the runtime-backed local registry, store, download/install, load, unload, removal, and session behavior while presenting the same `LocalLLMProvider` chat surface as provider products.

Existing runtime/session APIs remain available during migration, but new cross-provider work should move toward the provider-neutral request and stream shape documented in [docs/api-shape.md](docs/api-shape.md).

## Model Selection

Models are identified by both provider and model name. This avoids collisions when different providers use the same public model name and gives app code a stable value to store, compare, and display:

```swift
let localModelID = LLMModelID(
    providerID: LLMProviderID(rawValue: "mlx"),
    modelName: "phi-3.5-mini"
)

print(localModelID.description) // mlx:phi-3.5-mini
```

Use `availableModels()` when a provider can expose a catalog. Each `LLMModelDescriptor` includes a display name, conservative text/chat capabilities, optional default settings, and provider-owned metadata such as a local repository name or hosted vendor label:

```swift
let models = try await provider.availableModels()

for model in models {
    print(model.displayName, model.id.description)
}
```

The core package preserves provider metadata but does not interpret provider-specific keys. See [docs/model-manifest.md](docs/model-manifest.md) for the manifest shape and migration notes.

## Context

`yLLMKit` does not own your app database, document store, search index, citation UI, or source-of-truth data.

Apps can gather their own context and pass it as messages. Apps may also use `yLLMKitContext` to store app-supplied text, chunk long sources, maintain summaries, and build prompt-ready context packages.

If a model response proposes changing app data, treat the response as a proposal. Let the user review, accept, edit, or reject the change before your app writes anything.

See [docs/context-integration.md](docs/context-integration.md).

## Documentation

- [Changelog](CHANGELOG.md)
- [Architecture](docs/architecture.md)
- [API Shape](docs/api-shape.md)
- [Beta Readiness](docs/beta-readiness.md)
- [Context Integration](docs/context-integration.md)
- [Continuous Integration](docs/ci.md)
- [Model Manifests](docs/model-manifest.md)
- [Performance and Cancellation](docs/performance-and-cancellation.md)
- [Release Process](docs/release.md)
- [Contributing](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)

## Development

```sh
swift build
swift test
```

CI uses the same package test entry point:

```sh
./scripts/ci-test.sh
```

To run a live MLX download/inference smoke test, opt in explicitly:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
./scripts/prepare-mlx-metallib.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer YLLMKIT_RUN_MLX_SMOKE=1 swift test --enable-xctest --disable-swift-testing --filter yLLMKitMLXTests.testLiveMLXSmokeWhenEnabled
```

The smoke test defaults to `phi-2`. To use another supported model:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer YLLMKIT_RUN_MLX_SMOKE=1 YLLMKIT_MLX_SMOKE_MODEL=fast-local-assistant swift test --enable-xctest --disable-swift-testing --filter yLLMKitMLXTests.testLiveMLXSmokeWhenEnabled
```

Hosted provider smoke tests are also opt-in and require credentials plus an explicit model name:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer OPENAI_API_KEY=... YLLMKIT_RUN_OPENAI_SMOKE=1 YLLMKIT_OPENAI_SMOKE_MODEL=... swift test --enable-xctest --disable-swift-testing --filter yLLMKitOpenAITests.testLiveOpenAISmokeWhenEnabled
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ANTHROPIC_API_KEY=... YLLMKIT_RUN_ANTHROPIC_SMOKE=1 YLLMKIT_ANTHROPIC_SMOKE_MODEL=... swift test --enable-xctest --disable-swift-testing --filter yLLMKitAnthropicTests.testLiveAnthropicSmokeWhenEnabled
```
