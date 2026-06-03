# Security Policy

yLLMKit is an early-development Swift package for text/chat LLM integration. Security issues may affect application credentials, hosted provider requests, local model storage, context persistence, or prompt data handled by consuming apps.

## Reporting a Vulnerability

Do not open a public issue with exploit details, API keys, private prompts, or user data. If GitHub private vulnerability reporting is enabled for this repository, use that channel. If it is not available, open a minimal public issue asking for a private disclosure contact and include no sensitive details.

Please include the affected product, package version or commit, platform, reproduction steps, and expected impact once a private channel is established.

## Supported Versions

This project has not yet published a stable `1.0.0` release. Security fixes are expected to land on `main` until versioned releases begin.

## Credential Handling

Applications using hosted providers should store API keys in their own secure configuration and pass them into provider configuration at runtime. Do not commit real API keys, bearer tokens, provider credentials, private prompts, downloaded private model data, or user context databases.

The provider products normalize request and stream handling, but consuming apps remain responsible for access control, consent, retention, deletion, logging policy, and review of model-suggested changes before writing to app-owned data.
