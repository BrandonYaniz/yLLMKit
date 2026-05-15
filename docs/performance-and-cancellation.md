# Performance and Cancellation

Speed and reliability are primary goals.

## Metrics

Every completed generation should be able to report:

```swift
public struct LLMPerformanceMetrics: Codable, Sendable, Equatable {
    public var modelID: String
    public var promptTokenCount: Int?
    public var outputTokenCount: Int?
    public var loadTimeSeconds: Double?
    public var firstTokenLatencySeconds: Double?
    public var totalGenerationSeconds: Double?
    public var tokensPerSecond: Double?
    public var wasWarm: Bool
}
```

## Required Measurements

Benchmark harness should measure:

- Cold model load time.
- Warm generation time.
- First-token latency.
- Tokens per second.
- Memory behavior, if accessible.
- Cancellation behavior.

## Cancellation Requirements

Cancellation must be designed into the session layer from the start.

Expected behavior:

- A stream can be cancelled by cancelling the parent Swift task.
- A session can also expose `cancel()`.
- Cancellation should return a clean finish reason when possible.
- Cancellation should not corrupt the loaded model state.
- A new generation should be possible after cancellation unless the backend reports otherwise.

## Performance Rules

- Keep loaded models warm.
- Avoid reloading per prompt.
- Avoid `@MainActor` inside core runtime.
- Avoid appending to a UI string on every token inside the backend.
- Stream tokens and let the UI decide how often to render.
- Preflight unsupported capabilities before generation.

## App Integration Tips

- Load a model before the user starts a latency-sensitive workflow.
- Reuse a session when the user is having a continuous interaction with the same model.
- Cancel in-flight generation when the user edits the prompt or starts a new request.
- Show download and load progress separately from generation progress.
- Surface model size and memory requirements before download when that metadata is available.
