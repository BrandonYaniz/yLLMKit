# yLLMKit

`yLLMKit` is a Swift package for building text/chat LLM features with a small provider-neutral core and optional provider products.

The package is moving from a local-only MLX runtime toward one shared chat interface that can support local and remote models without making the core target depend on any one provider.

## Status

This project is in early development.

The repository currently contains the original core runtime work and the `yLLMKitMLX` local inference product. The active roadmap is refactoring that foundation toward this product shape:

```text
yLLMKit
yLLMKitMLX
yLLMKitOpenAI
yLLMKitAnthropic
yLLMKitContext
```

The v1 scope is text/chat only. Vision, audio, images, tool calling, function calling, embeddings, agents, realtime APIs, file uploads, workflow orchestration, and UI components are out of scope for v1.

## Design Goals

- Keep `yLLMKit` core small, UI-neutral, and provider-neutral.
- Put MLX, OpenAI, Anthropic, GRDB, and other concrete dependencies in optional products.
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

### yLLMKitMLX

Local Apple Silicon inference through MLX. This product owns local model catalog, download, preparation, loading, streaming, cancellation, and MLX-specific mapping.

### yLLMKitOpenAI

Planned optional OpenAI text/chat provider. This product will own OpenAI request mapping, streaming mapping, usage mapping, configuration, and error normalization.

### yLLMKitAnthropic

Planned optional Anthropic text/chat provider. This product will own Anthropic request mapping, streaming mapping, usage mapping, configuration, and error normalization.

### yLLMKitContext

Planned optional context layer for conversation transcripts, app-supplied text sources, token-aware chunking, hierarchical summaries, source references, prompt budgeting, and GRDB-backed persistence.

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

## Target API Direction

The public cross-provider direction is request-based text/chat:

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

Provider products conform to the shared `LLMProvider` interface and stream `LLMStreamEvent` values. Existing runtime/session APIs may remain during migration, but new cross-provider work should move toward the provider-neutral request and stream shape documented in [docs/api-shape.md](docs/api-shape.md).

## Context

`yLLMKit` does not own your app database, document store, search index, citation UI, or source-of-truth data.

Apps can gather their own context and pass it as messages. Apps may also use the planned `yLLMKitContext` product to store app-supplied text, chunk long sources, maintain summaries, and build prompt-ready context packages.

If a model response proposes changing app data, treat the response as a proposal. Let the user review, accept, edit, or reject the change before your app writes anything.

See [docs/context-integration.md](docs/context-integration.md).

## Documentation

- [Architecture](docs/architecture.md)
- [API Shape](docs/api-shape.md)
- [Context Integration](docs/context-integration.md)
- [Model Manifests](docs/model-manifest.md)
- [Performance and Cancellation](docs/performance-and-cancellation.md)

## Development

```sh
swift build
swift test
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
