# Release Process

yLLMKit is currently pre-1.0. The release process should keep external users clear on compatibility, required toolchains, and which APIs are expected to remain stable.

## Versioning

Use semantic versioning once tagged releases begin. Before `1.0.0`, minor versions may include API changes while the text/chat v1 surface settles. Patch versions should be reserved for compatible fixes and documentation corrections.

Provider products should remain independently optional. A release should not make `yLLMKit` core depend on MLX, hosted provider transports, GRDB, or other concrete provider dependencies.

## Pre-Release Checklist

- Confirm the README status, requirements, installation instructions, and product list are current.
- Review the beta contract in `docs/beta-readiness.md` for scope, API status, validation gates, and known limitations.
- Update `CHANGELOG.md` with the release date and user-facing changes.
- Run `./scripts/ci-test.sh` on a complete macOS Swift/Xcode installation.
- Run live MLX smoke tests when MLX model preparation, loading, prompting, streaming, or cancellation changed.
- Run hosted provider smoke tests when OpenAI or Anthropic request mapping, stream parsing, usage mapping, error mapping, or configuration changed.
- Confirm provider examples do not contain real credentials.
- Review public API changes against `docs/api-shape.md`.
- Confirm `Package.resolved` reflects intentional dependency updates.
- Tag the release from a clean working tree.

## Release Notes

Release notes should call out public API changes, provider behavior changes, dependency or platform requirement changes, migration guidance, and known limitations. Keep opt-in validation steps, such as live MLX smoke tests, separate from the default CI result so consumers can understand what was covered by automation.
