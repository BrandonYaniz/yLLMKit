# Demo App Roadmap

This plan gets yLLMKit to a useful demo app in small commits. The demo should prove four things:

- The app can show a supported LLM list.
- The app can tell whether each supported model is already installed.
- The app can download, install, remove, and load models.
- The app can talk to a loaded model and stream responses.

## Target Demo Shape

Build a small macOS SwiftUI app that depends on this package locally. Keep the app thin: UI state and controls live in the demo app, while model discovery, install state, downloading, loading, sessions, streaming, cancellation, and errors come from yLLMKit APIs.

The first working backend should be MLX on Apple Silicon. Until the MLX backend is ready, use an in-package mock backend so the demo UI and runtime contracts can be tested without downloading multi-GB model files.

## Milestone 1: Model Catalog

Commit message: `Add model catalog types`

Add the model-management value types under `Sources/yLLMKit/Models/`:

- `ModelDescriptor`
- `ModelCapabilities`
- `ModelManifest`
- `ModelDownloadRequest`
- `ModelDownloadProgress`
- `LocalModel`

Add manifest decoding tests using `examples/sample-model-manifest.json`.

Done when app-facing model IDs, backend IDs, provider metadata, capabilities, recommended memory, and default generation settings round trip through Codable.

## Milestone 2: Model Registry

Commit message: `Add model registry`

Add a `ModelRegistry` actor that can load bundled or app-supplied manifests and expose:

- `supportedModels()`
- `model(id:)`
- `models(forBackend:)`

The registry should not know how to download or run models. It only answers what yLLMKit supports.

Done when tests can load the sample manifest and retrieve a model by stable app-facing ID.

## Milestone 3: Local Model Store

Commit message: `Track local models`

Add a `ModelStore` protocol and a file-backed implementation for the local model cache. It should answer:

- whether a supported model is installed
- where that model lives on disk
- basic installed metadata, including install date and size when known
- delete/remove operations

Keep the default storage root configurable so the demo can use a sandbox-friendly app support folder.

Done when tests can create a temporary store, register an installed model, find it, and remove it.

## Milestone 4: Backend Protocols

Commit message: `Define backend runtime protocols`

Add the runtime protocols described in the API docs:

- `LLMBackend`
- `LoadedModel`
- `LLMSession`
- `LLMRuntime`

`LLMRuntime` should compose a registry, model store, and one or more backends. It should route operations by `backendID`, validate capabilities before use, and keep loaded models warm.

Done when tests can use a fake backend to list supported models, load a model, create a session, and stream deterministic tokens.

## Milestone 5: Download Management

Commit message: `Add model downloads`

Add download coordination that reports an `AsyncThrowingStream<ModelDownloadProgress, Error>`. Support:

- queued download start
- progress bytes and phase reporting
- cancellation
- install finalization into `ModelStore`
- cleanup after failed or cancelled downloads

The first implementation can support Hugging Face repositories through backend-specific download code, but the public API should stay backend-neutral.

Done when fake download tests cover progress, success, cancellation, and failed cleanup.

## Milestone 6: Mock Backend Demo

Commit message: `Add demo app shell`

Create an example SwiftUI app under `Examples/LocalLLMDemo/` that uses a mock backend. The UI should have:

- a supported model list
- install state badges
- download/install/remove controls
- load/unload controls
- a chat panel that streams mock tokens
- cancel generation
- visible error handling

Done when the demo app works without network access or real model files.

## Milestone 7: MLX Backend

Commit message: `Add MLX backend`

Add the first real local inference backend under `Sources/yLLMKit/Backends/MLX/`. Start with one small approved model from the manifest. The backend should:

- map yLLMKit model descriptors to MLX-compatible repositories
- download or reuse local model artifacts
- load a model once
- create chat sessions
- stream generated tokens
- support cancellation

Done when the demo can download, load, and chat with the approved model on Apple Silicon.

## Milestone 8: Demo Polish

Commit message: `Polish local LLM demo`

Make the demo useful for package validation:

- show model size and recommended memory
- separate download, install, load, and generation state
- show first-token latency and tokens per second
- disable invalid actions
- keep the model warm while the window is active
- cancel cleanly when the user starts a new prompt

Done when the demo can exercise the full package workflow repeatedly without restarting the app.

## Milestone 9: Docs and Package Examples

Commit message: `Document the demo workflow`

Update `README.md` and docs with:

- the supported model workflow
- demo app setup instructions
- expected storage locations
- supported hardware notes
- troubleshooting for missing model files, cancellation, and backend errors

Done when a new contributor can clone the repo, run tests, open the demo, install a supported model, and send a prompt.

## Recommended Implementation Order

1. Build and test the API contracts with fake backends first.
2. Wire the demo app to those contracts before adding MLX.
3. Add real downloads and MLX behind the same contracts.
4. Keep the public package UI-neutral and move all SwiftUI concerns into the demo app.

This keeps each commit reviewable and lets the demo app progress before the real inference backend is fully stable.
