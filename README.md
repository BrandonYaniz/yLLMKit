# yLLMKit

`yLLMKit` is a Swift package for adding local large language model support to Swift applications.

The goal is to make common local LLM tasks straightforward: discover supported models, check what is installed, download a selected model, load it efficiently, and stream responses back into your app.

## Status

This project is in early development. The package now includes runtime-neutral core types, model manifests, a model registry, a file-backed local model store, backend/session protocols, runtime routing, download/install progress handling, streaming response aggregation, and a mock backend for integration testing.

The MLX backend is available as a separate `yLLMKitMLX` product so apps that only need the core interfaces do not need to link MLX.

## Requirements

- Swift 6.2 or later.
- macOS 14 or later.
- Apple Silicon is recommended for local model inference.
- Full Xcode is required for live MLX smoke tests because MLX needs the Metal compiler.

The core package is UI-neutral. You can use it from SwiftUI, AppKit, command line tools, or other Swift application layers.

## Installation

Add `yLLMKit` to your Swift package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/BrandonYaniz/yLLMKit.git", branch: "main")
]
```

Then add the library product to your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "yLLMKit", package: "yLLMKit")
    ]
)
```

To use local MLX inference, add the MLX product as well:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "yLLMKit", package: "yLLMKit"),
        .product(name: "yLLMKitMLX", package: "yLLMKit")
    ]
)
```

If you are using Xcode:

1. Open your app project.
2. Select the project in the navigator.
3. Open **Package Dependencies**.
4. Add the repository URL for `yLLMKit`.
5. Add the `yLLMKit` product to the app target that will use local LLM features.

## Basic Usage

Import the package where you need LLM runtime types:

```swift
import yLLMKit
```

Create messages for a generation request:

```swift
let messages = [
    LLMMessage(
        role: .system,
        content: "Answer clearly and concisely."
    ),
    LLMMessage(
        role: .user,
        content: "Summarize the release notes in three bullets."
    )
]
```

Choose generation settings:

```swift
let settings = GenerationSettings.balanced
```

Configure a session:

```swift
let configuration = SessionConfiguration(
    systemPrompt: "You are a helpful assistant."
)
```

Create a model descriptor or load one from a manifest, then build a registry and local model store:

```swift
let model = ModelDescriptor(
    id: "fast-local-assistant",
    displayName: "Fast Local Assistant",
    backendID: "mock",
    provider: "local",
    repository: "models/fast-local-assistant",
    capabilities: .chatOnly(contextWindow: 4096),
    defaultSettings: .balanced
)

let registry = try ModelRegistry(models: [model])
let store = try FileModelStore(
    rootDirectory: FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    )[0].appendingPathComponent("yLLMKit")
)

let runtime = try LLMRuntime(
    modelRegistry: registry,
    modelStore: store,
    backends: [
        MockLLMBackend(models: [model])
    ]
)

try await runtime.loadModel(id: model.id)

let session = try await runtime.createSession(
    modelID: model.id,
    configuration: configuration
)

for try await token in session.streamResponse(
    to: messages,
    settings: settings
) {
    print(token.text, terminator: "")
}
```

The mock backend is useful for validating app integration. Real local inference will come from backend implementations such as MLX.

For MLX inference, import the MLX product and use the shared supported catalog:

```swift
import yLLMKit
import yLLMKitMLX

let registry = try ModelRegistry(models: SupportedModelCatalog.all)
let store = try FileModelStore(rootDirectory: modelStoreURL)
let runtime = try LLMRuntime(
    modelRegistry: registry,
    modelStore: store,
    backends: [MLXBackend()]
)

try await runtime.loadModel(id: "phi-3.5-mini")
```

## Model Workflow

The planned model workflow is:

1. Read a supported model manifest into `ModelRegistry`.
2. Show supported models from `runtime.supportedModels()`.
3. Check local install state with `runtime.isModelInstalled(_:)`.
4. Download and register a selected model with `runtime.downloadAndInstallModel(id:)`.
5. Load an installed model once with `runtime.loadModel(id:)`.
6. Create a session with `runtime.createSession(modelID:configuration:)`.
7. Stream generated tokens with `session.streamResponse(to:settings:)`.
8. Remove models through `runtime.removeModel(id:)` when the user uninstalls them.
9. Cancel generation cleanly when the user stops or changes a request.

Model IDs should come from manifests so app code does not need to hardcode provider-specific repository names.

## Supported Models

The built-in catalog currently declares these MLX-backed chat models:

- `fast-local-assistant`: `mlx-community/gemma-3-1b-it-qat-4bit`
- `phi-2`: `mlx-community/phi-2-hf-4bit-mlx`
- `phi-3.5-mini`: `mlx-community/Phi-3.5-mini-instruct-4bit`
- `phi-3.5-moe`: `mlx-community/Phi-3.5-MoE-instruct-4bit`

## Context

`yLLMKit` does not require a specific data source. Your app can pass plain user messages, retrieved document snippets, search results, form data, or any other text context as `LLMMessage` values.

Keep application-specific data ownership in your app. Use `yLLMKit` for model management and generation, and let your app decide how to gather context, display citations, or apply user-approved changes.

See [docs/context-integration.md](docs/context-integration.md) for more detail.

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

If Xcode reports that the Metal Toolchain is missing, install or export it first:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -downloadComponent MetalToolchain -exportPath /private/tmp/yLLMKit-MetalToolchain
hdiutil attach /private/tmp/yLLMKit-MetalToolchain/MetalToolchain-*.exportedBundle/Restore/*.dmg -nobrowse -readonly -mountpoint /private/tmp/yLLMKit-MetalToolchainMount
METAL_TOOLCHAIN_DIR=/private/tmp/yLLMKit-MetalToolchainMount/Metal.xctoolchain ./scripts/prepare-mlx-metallib.sh
```

Development notes used by local tooling are kept outside the public documentation path and are ignored by git.
