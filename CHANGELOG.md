# Changelog

All notable changes to yLLMKit will be documented in this file.

This project is in early development and has not tagged a stable `1.0.0` release. Until then, public APIs may change as the package settles around the text/chat v1 scope described in the README.

## Unreleased

### Added

- Provider-neutral text/chat core APIs.
- Optional MLX, OpenAI, Anthropic, and context products.
- Documentation for architecture, provider setup, model manifests, context integration, cancellation, and CI.
- GitHub Actions CI for package tests.

### Changed

- Stabilized the provider-neutral chat request, stream, response, usage, cancellation, and error shapes.

## Release Notes Policy

Each release should add a dated section above `Unreleased` with user-facing changes grouped under `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, and `Security` when those categories apply.
