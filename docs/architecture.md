# yLLMKit Architecture

## High-Level Pattern

```text
App UI
  ↓
App-specific context gathering
  ↓
Context assembly
  ↓
yLLMKit runtime
  ↓
Backend implementation, beginning with MLX
  ↓
Model inference
```

## Library Responsibility

yLLMKit owns:

- LLM backend protocols.
- Model descriptors.
- Model capabilities.
- Download requests.
- Download progress reporting.
- Local model cache interface.
- Model loading and unloading.
- Runtime/session creation.
- Chat messages.
- Generation settings.
- Streaming token responses.
- Cancellation.
- Runtime metrics.
- Error types.
- Optional tool-call interface definitions.

yLLMKit does not own:

- App databases.
- Document stores.
- Search indexes.
- Retrieval or ranking logic.
- App-specific schemas.
- Citation UI.
- Direct mutation of app data.
- App-specific prompt policies.

## Recommended Repository Structure

```text
yLLMKit/
  Package.swift
  README.md
  LICENSE
  Sources/
    yLLMKit/
      Core/
        LLMBackend.swift
        LLMRuntime.swift
        LLMSession.swift
        LLMMessage.swift
        LLMRequest.swift
        LLMResponse.swift
        LLMToken.swift
        GenerationSettings.swift
        SessionConfiguration.swift
        LLMError.swift

      Models/
        ModelDescriptor.swift
        ModelCapabilities.swift
        ModelManifest.swift
        ModelDownloadRequest.swift
        ModelDownloadProgress.swift
        LocalModel.swift
        ModelStore.swift
        ModelRegistry.swift

      Backends/
        MLX/
          MLXBackend.swift
          MLXModelLoader.swift
          MLXModelStore.swift
          MLXSession.swift
          MLXModelMapping.swift

      Metrics/
        LLMPerformanceMetrics.swift
        TokenUsage.swift

      Tools/
        LLMTool.swift
        ToolCall.swift
        ToolResult.swift
        ToolRegistry.swift

  Tests/
    yLLMKitTests/
      CoreTypeTests.swift
      ManifestTests.swift
      RuntimeTests.swift
      StreamingTests.swift
      CancellationTests.swift

  Examples/
    BasicChat/
      README.md
```

## Design Rules

- Core runtime must be UI-neutral.
- Core runtime must avoid `@MainActor`.
- Streaming should use `AsyncThrowingStream`.
- Mutable model state should be isolated using actors or backend-specific isolation.
- App-specific context should enter yLLMKit as messages or tool results, not as database connections.
- Model IDs and backend details should live in manifests, not scattered throughout app code.
