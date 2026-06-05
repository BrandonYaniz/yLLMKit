# Beta Readiness

yLLMKit is pre-1.0. A beta release should be useful for real app integration while still allowing public API changes before `1.0.0`.

This document defines the beta contract for the current local-first text/chat v1 roadmap.

## Beta Scope

The beta scope is local-first provider-neutral text/chat with optional remote and context products:

```text
yLLMKit
yLLMKitMLX
yLLMKitOpenAI
yLLMKitAnthropic
yLLMKitContext
```

Beta includes:

- Provider-scoped model identifiers.
- Provider-neutral chat requests, messages, streamed events, responses, settings, usage, and normalized provider errors.
- MLX local text/chat lifecycle, preparation, progress, and streaming through local and shared provider APIs.
- OpenAI text/chat streaming through the shared provider API as a courtesy integration.
- Anthropic text/chat streaming through the shared provider API as a courtesy integration.
- Context storage, FTS search, token-estimate chunking, minimal provider-backed summarization, deterministic prompt budgeting, source references, and prompt-ready message construction.
- Mock provider behavior for tests and examples.

Beta does not include:

- Vision, audio, images, multimodal messages, tools, function calling, embeddings, agents, realtime APIs, file uploads, workflow orchestration, or UI.
- App-owned source-of-truth storage.
- Direct mutation of app data.
- PDF, DOCX, EPUB, OCR, web scraping, or native document parsing in `yLLMKitContext`.
- Provider-specific advanced APIs beyond the generic provider options escape hatch.

## Supported API Surface

The primary beta integration surface is the provider API documented in `docs/api-shape.md`:

- `LLMProvider`
- `LLMProviderID`
- `LLMModelID`
- `LLMModelDescriptor`
- `LLMModelCapabilities`
- `LLMMessage`
- `LLMChatRequest`
- `LLMStreamEvent`
- `LLMChatResponse`
- `GenerationSettings`
- `LLMUsage`
- `LLMProviderOptions`
- `LLMProviderError`

New cross-provider app code should use this surface.

Local-first app code should also use the local provider refinement:

- `LocalLLMProvider`
- `LocalModel`
- `ModelDownloadProgress`

The local refinement preserves lifecycle behavior that hosted providers do not naturally have, including installed-model listing, prepared-state checks, progress reporting, unload, and removal.

Hosted-provider app code may use the remote provider refinement:

- `RemoteLLMProvider`

The remote refinement keeps hosted configuration validation separate from local lifecycle behavior.

Existing runtime and local model APIs remain available during beta as local-runtime implementation and compatibility support:

- `LLMRuntime`
- `RuntimeLocalLLMProvider`
- `LLMBackend`
- `LLMSession`
- `ModelDescriptor`
- `ModelRegistry`
- `ModelStore`
- `LocalModel`

These APIs are not the preferred remote-provider direction, but they still represent important local-first functionality. They should not be removed until `LocalLLMProvider` and provider-specific local lifecycle APIs fully cover their public value.

## Provider Contract

Every beta provider should:

- Expose a stable `providerID`.
- Return provider-scoped model descriptors from `availableModels()` when a catalog is available.
- Validate model/provider mismatches and report `LLMProviderError.modelNotFound`.
- Validate required configuration during `prepareModel(_:)`.
- Stream through `AsyncThrowingStream<LLMStreamEvent, Error>`.
- Emit `.started`, `.textDelta`, and `.completed` for successful streams.
- Report usage when the provider makes it available.
- Map common authentication, rate limit, invalid request, transport, provider, and cancellation failures into `LLMProviderError`.
- Avoid `@MainActor` coupling.

MLX may use `prepareModel(_:)` for local download, load, warmup, or install validation.

Remote providers may use `prepareModel(_:)` for configuration validation or a no-op when configuration and model catalogs do not require work.

Every beta remote provider should:

- Conform to `LLMProvider` for shared chat behavior.
- Conform to `RemoteLLMProvider` for hosted configuration validation.
- Keep API keys and credentials in consuming app runtime configuration.
- Avoid adding hosted-only concepts to local lifecycle requirements.

## Local-First Contract

Local providers are first-class. Hosted providers exist to let developers use one familiar package across local and remote model strategies, not to constrain local functionality.

Every beta local provider should:

- Conform to `LLMProvider` for shared chat behavior.
- Conform to `LocalLLMProvider` for local lifecycle behavior.
- Report locally known models through `localModels()`.
- Report whether a model is ready enough for local chat through `isModelPrepared(_:)`.
- Expose preparation progress through `prepareModelWithProgress(_:)`.
- Support explicit unload when a loaded local model should release resources.
- Support removal of provider-owned local model state where practical.
- Keep local lifecycle, cache, memory, and model metadata out of remote provider requirements.

`LLMRuntime`, `LLMBackend`, `LLMSession`, and `ModelDescriptor` may continue to support the local runtime while the local provider refinement matures.

`RuntimeLocalLLMProvider` is the compatibility adapter for runtime-backed local apps that want to adopt `LocalLLMProvider` without giving up existing runtime install, load, unload, removal, and session behavior.

## Context Contract

`yLLMKitContext` beta should preserve the app-owned source-of-truth model:

- Raw transcript and source text are authoritative.
- Chunks, snapshots, memory items, summaries, and prepared contexts are derived artifacts.
- Apps decide whether model output proposes, previews, or applies changes.
- Apps remain responsible for source permissions, data retention, deletion, logging, and user review.

The current beta-ready context surface is deterministic context preparation:

- Context source and transcript types.
- Source references.
- GRDB-backed storage.
- FTS search.
- Token-estimate chunking.
- Minimal provider-backed summarization for summary chunks and conversation snapshots.
- Prompt budgeting.
- Prompt-ready `LLMMessage` output.

Provider-backed summarization is intentionally minimal for beta. It creates derived summary chunks and conversation snapshots through a caller-supplied `LLMProvider`; apps still choose when to persist those derived artifacts.

## Validation Gates

A beta tag should not be cut unless these pass from a clean working tree:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/ci-test.sh
```

The default CI/test gate covers unit and mock-provider behavior. Live provider validation is intentionally opt-in.

Run the live MLX smoke test when MLX model preparation, loading, prompting, streaming, cancellation, model catalog, Metal setup, or dependency versions change:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
./scripts/prepare-mlx-metallib.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer YLLMKIT_RUN_MLX_SMOKE=1 swift test --enable-xctest --disable-swift-testing --filter yLLMKitMLXTests.testLiveMLXSmokeWhenEnabled
```

OpenAI and Anthropic live smoke tests are opt-in and use environment variables for credentials and model names.

## Documentation Gates

Before a beta tag:

- README status must say beta or pre-beta accurately.
- README examples must match compiled public APIs.
- Provider setup instructions must avoid real credentials.
- Public API changes must be reflected in `docs/api-shape.md`.
- Context behavior must be reflected in `docs/context-integration.md`.
- Known limitations must be included in release notes.
- `CHANGELOG.md` must include a dated beta section.

## Beta Exit Criteria

The project is ready for a first beta when:

- The provider API is the clearly documented primary integration surface.
- Local-first lifecycle behavior is available through `LocalLLMProvider` or explicitly documented local-runtime APIs.
- Existing local runtime APIs have an explicit implementation, compatibility, or migration status.
- Core, MLX, OpenAI, Anthropic, and Context products build and pass default tests.
- Live MLX smoke has been run on a compatible Apple Silicon machine, or release notes clearly say it was not run.
- Hosted provider live smoke tests have been run with explicit model environment variables, or release notes clearly limit hosted validation to mocked transports.
- Documentation explains what is supported, what is deferred, and how to validate a consuming app integration.
