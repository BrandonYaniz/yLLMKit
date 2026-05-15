# Model Manifest

Use model manifests to prevent app code from hardcoding raw Hugging Face model IDs everywhere.

## Example

```json
{
  "id": "fast-local-assistant",
  "displayName": "Fast Local Assistant",
  "backendID": "mlx",
  "provider": "huggingface",
  "repository": "mlx-community/gemma-3-1b-it-qat-4bit",
  "revision": null,
  "recommendedRAMGB": 8,
  "capabilities": {
    "supportsChat": true,
    "supportsCompletion": false,
    "supportsVision": false,
    "supportsEmbeddings": false,
    "supportsToolCalling": false,
    "supportsJSONMode": false,
    "contextWindow": 32768,
    "preferredMaxOutputTokens": 4096
  },
  "defaultSettings": {
    "temperature": 0.7,
    "topP": 0.9,
    "maxTokens": 2048,
    "repetitionPenalty": null,
    "stopSequences": []
  }
}
```

## Manifest Rules

- Every model must have a stable app-facing `id`.
- App code should use the app-facing `id`, not raw repository names.
- `backendID` routes the model to the correct backend.
- Capabilities must be explicit.
- Context window values should be treated as declared capability, not a guarantee of practical speed.
- v1 should support one or two approved models only.
