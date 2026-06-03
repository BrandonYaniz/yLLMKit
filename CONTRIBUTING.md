# Contributing

Thanks for taking the time to improve yLLMKit. The package is still early, so contributions should keep the v1 scope tight: provider-neutral text/chat primitives, optional provider products, local MLX support, and app-owned context preparation.

## Development Setup

Use Swift 6.2 or later on macOS 14 or later. Apple Silicon is recommended when working on `yLLMKitMLX`, and full Xcode is required for live MLX smoke tests because MLX needs the Metal compiler.

Run the default validation before opening a pull request:

```sh
swift build
swift test
./scripts/ci-test.sh
```

`scripts/ci-test.sh` uses a clean scratch path and mirrors the GitHub Actions package test entry point. If local XCTest launch fails after the package builds, check the Xcode selection documented in `docs/ci.md`.

## Contribution Guidelines

- Keep `yLLMKit` core UI-neutral and provider-neutral.
- Put provider-specific transport, request mapping, event parsing, usage mapping, and error normalization in the matching provider product.
- Keep concrete dependencies optional whenever a target does not need them.
- Preserve app ownership of source-of-truth data. Model output that proposes changing app data should remain a proposal until the app or user accepts it.
- Add or update focused tests for behavioral changes, especially streaming, cancellation, provider error mapping, usage reporting, context budgeting, and persistence behavior.
- Update README or docs when changing public API, setup steps, provider behavior, or release expectations.

## Pull Request Checklist

- The change is scoped to the product or docs area it affects.
- Public API changes are reflected in docs or examples.
- Default package tests pass, or the PR explains why a local environment could not run them.
- Live MLX smoke tests are run only when the change affects MLX model preparation, loading, prompting, streaming, or cancellation.
- No real API keys, tokens, model credentials, or private prompts are committed.
