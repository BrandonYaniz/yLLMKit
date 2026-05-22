# yLLMKit

`yLLMKit` is a Swift package for building text/chat LLM features with a small provider-neutral core and optional provider products.

The package gives Swift developers one shared chat interface for local and remote language models without forcing every app target to carry every provider dependency. Apps can start with the lightweight core types, add MLX for on-device Apple Silicon inference, add hosted providers such as OpenAI or Anthropic when remote models make sense, and use the context layer when prompts need structured source material instead of ad hoc string assembly.

This shape keeps product code flexible as model strategy changes. A SwiftUI app, AppKit app, command line tool, or service layer can build around the same request, response, streaming, settings, usage, and error types while still leaving provider-specific behavior in the product that owns it. That makes it easier to prototype with a mock backend, ship a local-first experience, fall back to remote models, or swap providers without rewriting the application layer that prepares conversations and consumes streamed output.

## Status

This project is in early development.

The repository currently contains this product shape:

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

The core product is the stable integration point for application code. It lets developers model conversations, generation settings, model identifiers, streaming events, usage, and provider errors once, then route requests to whichever provider product fits the current feature. Because it stays UI-neutral and provider-neutral, the same core layer can sit behind SwiftUI, AppKit, command line, or service code without pulling MLX, HTTP provider clients, GRDB, or other concrete dependencies into targets that do not need them.

### yLLMKitMLX

Local Apple Silicon inference through MLX. This product owns local model catalog, download, preparation, loading, streaming, cancellation, and MLX-specific mapping.

`yLLMKitMLX` brings local inference into the same chat shape as the rest of the package. Developers can offer offline or privacy-sensitive text generation, manage supported local models, surface preparation and streaming behavior, and cancel work without designing a separate app architecture for on-device models. Keeping MLX-specific catalog, download, loading, and prompt mapping here also means apps can add local Apple Silicon support without making the core package depend on MLX.

### yLLMKitOpenAI

Optional OpenAI text/chat provider. This product owns OpenAI request mapping, streaming mapping, usage mapping, configuration, and error normalization.

`yLLMKitOpenAI` lets developers use OpenAI models through the same provider-neutral request and stream interface they use elsewhere in the package. The app can keep its chat orchestration, cancellation handling, settings, and response rendering consistent while the provider product handles OpenAI-specific transport details, event parsing, usage reporting, and error normalization. That separation makes it practical to support hosted models without scattering provider-specific JSON and networking concerns throughout the app.

### yLLMKitAnthropic

Optional Anthropic text/chat provider. This product owns Anthropic request mapping, streaming mapping, usage mapping, configuration, and error normalization.

`yLLMKitAnthropic` gives developers access to Anthropic text/chat models without changing the application-facing chat model. Provider-specific request formats, server-sent events, usage metadata, configuration, and error mapping stay inside the Anthropic product, while app code continues to work with shared `LLMChatRequest`, `LLMStreamEvent`, and response types. This is useful for apps that want to compare providers, offer provider choice, or keep a remote fallback available beside local inference.

### yLLMKitContext

Optional context layer for conversation transcripts, app-supplied text sources, token-aware chunking, hierarchical summaries, source references, prompt budgeting, and GRDB-backed persistence.

`yLLMKitContext` helps developers turn app-owned text into prompt-ready context without giving up control of the source of truth. It can store transcripts and source records, split long material into useful chunks, maintain summaries, preserve source references, and build context packages that fit a prompt budget. That gives apps a reusable foundation for document-aware or memory-aware chat features while still letting the app decide what data is authoritative and how model suggestions become user-reviewed changes.

## Demo

A Swift project demonstrating this library is available at [BrandonYaniz/yLLMKit-Demo](https://github.com/BrandonYaniz/yLLMKit-Demo).

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

Apps can gather their own context and pass it as messages. Apps may also use `yLLMKitContext` to store app-supplied text, chunk long sources, maintain summaries, and build prompt-ready context packages.

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
