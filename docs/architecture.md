# yLLMKit Architecture

## High-Level Pattern

```text
App UI or service layer
  ↓
Optional app-specific retrieval
  ↓
Optional yLLMKitContext prompt preparation
  ↓
yLLMKit provider-neutral chat request
  ↓
Concrete provider product
  ↓
Local or remote model
  ↓
Streamed or complete text response
```

yLLMKit is local-first. Hosted provider products exist so developers can use one familiar package across local and remote model strategies, but remote behavior should not constrain local model lifecycle, cache, memory, or preparation APIs.

## Product Layout

```text
Sources/
  yLLMKit/
    Core provider-neutral text/chat interfaces

  yLLMKitMLX/
    Local MLX provider implementation

  yLLMKitOpenAI/
    OpenAI provider implementation

  yLLMKitAnthropic/
    Anthropic provider implementation

  yLLMKitContext/
    Optional context optimization, memory, chunking, summaries, and prompt budgeting
```

## Library Responsibility

### yLLMKit core owns

- Provider protocols.
- Model identifiers.
- Model descriptors.
- Model capabilities.
- Chat messages.
- Chat requests.
- Chat responses.
- Streaming events.
- Generation settings.
- Usage metadata.
- Error normalization.
- Provider-specific option escape hatch.
- Mock/testing basics where lightweight.

### Provider products own

- Provider-specific request mapping.
- Provider-specific streaming mapping.
- Provider-specific authentication/configuration.
- Provider-specific model catalogs where useful.
- Provider-specific error mapping.
- Provider-specific dependencies.

### Local provider products own

- Local model installation and discovery.
- Download, verification, preparation, loading, warmup, unloading, and removal behavior.
- Local preparation progress reporting.
- Local memory and cache policy.
- Local model metadata that does not apply to hosted providers.

### yLLMKitContext owns

- Conversation transcripts.
- Text document sources.
- Token-aware chunking.
- Oversized text splitting.
- Hierarchical summaries.
- Conversation snapshots.
- Context budget building.
- Source references.
- GRDB-backed persistence.
- FTS search.
- Power-aware rebuild behavior.

## Core Must Not Own

- MLX imports.
- OpenAI HTTP implementation.
- Anthropic HTTP implementation.
- GRDB.
- SQLite schema.
- Context database.
- Document parsing for PDFs, DOCX, EPUB, or web pages.
- Vision, audio, images, tools, function calling, embeddings, agents, or realtime APIs in v1.
- UI.
- Direct mutation of app data.

## Design Rules

- v1 is text/chat only.
- Core provider layer must be UI-neutral.
- Core provider layer must avoid `@MainActor` unless a specific API requires it.
- Streaming should use `AsyncThrowingStream`.
- Local model lifecycle behavior should stay in local provider products or local-provider refinements.
- Provider-specific dependencies must stay in provider products.
- Context summaries are derived artifacts, not authoritative source records.
- Raw transcripts and raw source text remain authoritative.
- Apps decide whether a model response proposes, previews, or applies changes.
- App-specific source-of-truth databases stay in the app or in purpose-built libraries such as yContinuityKit.
