# Changelog

All notable changes to yLLMKit will be documented in this file.

This project is in early development and has not tagged a stable `1.0.0` release. Until then, public APIs may change as the package settles around the text/chat v1 scope described in the README.

## Unreleased

### Added

- Provider-neutral text/chat core APIs.
- Optional MLX, OpenAI, Anthropic, and context products.
- `LocalLLMProvider` for local-first lifecycle operations, including installed-model listing, preparation progress, readiness checks, unload, and removal.
- `RemoteLLMProvider` for hosted-provider configuration validation without forcing hosted providers into local lifecycle requirements.
- `RuntimeLocalLLMProvider` to adapt existing `LLMRuntime` integrations into the provider-first local API.
- Provider-scoped model IDs through `LLMProviderID` and `LLMModelID`.
- Local-first demo CLI commands for MLX preparation/chat and hosted-provider smoke checks.
- Opt-in live smoke tests for MLX, OpenAI, and Anthropic.
- Documentation for architecture, provider setup, model manifests, context integration, cancellation, and CI.
- GitHub Actions CI for package tests.

### Changed

- Stabilized the provider-neutral chat request, stream, response, usage, cancellation, and error shapes.
- Clarified that hosted providers are courtesy integrations and must not constrain local-first functionality.
- Clarified that `LLMRuntime`, `LLMBackend`, `LLMSession`, `ModelDescriptor`, `ModelRegistry`, and `ModelStore` remain local-runtime compatibility APIs during beta.
- `MLXProvider` can use a `ModelStore` for durable local model metadata across provider instances.

### Validation

- Default validation: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/ci-test.sh`.
- Latest recorded default validation: 96 tests, 0 failures, 3 skipped on June 4, 2026.
- Skipped by default: live MLX, OpenAI, and Anthropic smoke tests.

### Known Limitations

- v1 scope is text/chat only. Vision, audio, images, tools/function calling, embeddings, agents, realtime APIs, file uploads, workflow orchestration, and UI components are out of scope.
- Live MLX validation requires Apple Silicon, a complete Xcode installation, the Metal toolchain, and explicit `YLLMKIT_RUN_MLX_SMOKE=1` opt-in.
- Live OpenAI and Anthropic validation requires runtime credentials plus explicit model environment variables.
- `yLLMKitContext` does not parse PDFs, DOCX, EPUB, OCR, web pages, or native document formats. Apps provide text sources.
- `yLLMKitContext` preserves app-owned source-of-truth data; model output should be treated as a proposal before app data is mutated.

## Release Notes Policy

Each release should add a dated section above `Unreleased` with user-facing changes grouped under `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, and `Security` when those categories apply.
