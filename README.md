# yLLMKit

`yLLMKit` is a Swift package for adding local large language model support to Swift applications.

The goal is to make common local LLM tasks straightforward: discover supported models, check what is installed, download a selected model, load it efficiently, and stream responses back into your app.

## Status

This project is in early development. The package currently contains the first public runtime-neutral types and will expand toward model manifests, model download/load support, streaming generation, cancellation, metrics, and an MLX backend for Apple Silicon Macs.

## Requirements

- Swift 6.2 or later.
- macOS 14 or later.
- Apple Silicon is recommended for local model inference.

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

The runtime and backend APIs are still being implemented. The intended usage shape is:

```swift
let runtime = LLMRuntime(backends: [MLXBackend()])

let model = try await runtime.modelRegistry.model(id: "fast-local-assistant")
try await runtime.loadModel(model)

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

## Model Workflow

The planned model workflow is:

1. Read the supported model manifest.
2. Show supported models in your app.
3. Check which supported models are already installed locally.
4. Download a selected model if needed.
5. Load the model once and keep it warm while the user is actively querying it.
6. Stream generated tokens into your app.
7. Cancel generation cleanly when the user stops or changes a request.

Model IDs should come from manifests so app code does not need to hardcode provider-specific repository names.

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

Development notes used by local tooling are kept outside the public documentation path and are ignored by git.
