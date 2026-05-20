# Model Manifests

Model manifests describe provider-scoped text/chat models without forcing app code to hardcode provider-specific names throughout the application.

The new provider direction uses `LLMModelID`:

```text
providerID + modelName
```

Examples:

```text
mlx:phi-3.5-mini
openai:gpt-...
anthropic:claude-...
```

## Target Shape

Manifests should align with `LLMModelDescriptor` and may include provider-owned metadata:

```json
{
  "id": {
    "providerID": "mlx",
    "modelName": "phi-3.5-mini"
  },
  "displayName": "Phi 3.5 Mini",
  "capabilities": {
    "supportsStreaming": true,
    "supportsLocalPreparation": true,
    "contextWindow": 131072,
    "maxOutputTokens": 4096
  },
  "defaultSettings": {
    "temperature": 0.7,
    "topP": 0.9,
    "maxOutputTokens": 2048,
    "stopSequences": []
  },
  "providerMetadata": {
    "repository": "mlx-community/Phi-3.5-mini-instruct-4bit",
    "revision": null,
    "recommendedRAMGB": 8
  }
}
```

`providerMetadata` is intentionally provider-owned catalog data. Core should preserve it but avoid interpreting MLX, OpenAI, Anthropic, or other provider-specific keys.

## Rules

- Every model ID must be provider-scoped.
- App code should use `LLMModelID`, not raw repository names.
- Capabilities must be explicit and conservative.
- Context window values are declared capability, not a guarantee of practical speed.
- v1 manifests are text/chat only.
- Do not add manifest fields for vision, audio, images, tool calling, function calling, embeddings, agents, realtime APIs, or file upload APIs in v1.

## Legacy Compatibility

The existing implementation still contains older `ModelDescriptor` fields such as `backendID`, `provider`, `repository`, and `preferredMaxOutputTokens`.

Those fields are migration inputs for the MLX provider alignment work. New public documentation and new roadmap work should prefer provider-scoped `LLMModelDescriptor` values.
