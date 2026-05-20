# Performance and Cancellation

Speed, predictable cancellation, and low UI coupling are primary goals.

## Metrics

Every completed generation should be able to report provider-neutral usage and timing metadata where available.

Suggested target shape:

```swift
public struct LLMPerformanceMetrics: Codable, Hashable, Sendable {
    public var modelID: LLMModelID
    public var inputTokenCount: Int?
    public var outputTokenCount: Int?
    public var preparationTimeSeconds: Double?
    public var firstTokenLatencySeconds: Double?
    public var totalGenerationSeconds: Double?
    public var tokensPerSecond: Double?
    public var wasPrepared: Bool?
}
```

Provider products may collect additional internal metrics, but core should expose only broadly useful text/chat metrics.

## Required Measurements

Benchmark harnesses should measure:

- Local model preparation time for providers that need preparation.
- Warm generation time.
- First-token latency.
- Tokens per second.
- Memory behavior, if accessible.
- Cancellation behavior.

Remote providers may not expose all measurements. Missing values should be optional rather than guessed.

## Cancellation Requirements

Cancellation must work through Swift task cancellation first.

Expected behavior:

- Cancelling the parent task should stop an in-flight stream.
- Provider products may expose additional cancellation hooks internally.
- Cancellation should finish cleanly when the provider can report it.
- Cancellation should not corrupt local loaded model state.
- A new generation should be possible after cancellation unless the provider reports otherwise.

## Performance Rules

- Keep provider calls off the main actor unless an API specifically requires it.
- Avoid appending to a UI string on every token inside provider code.
- Stream text deltas and let the UI decide how often to render.
- Preflight unsupported capabilities before generation when practical.
- Keep local models warm after preparation when memory policy allows.
- Do not force remote providers into local session semantics.

## App Integration Tips

- Prepare a local model before the user starts a latency-sensitive workflow.
- Cancel in-flight generation when the user edits the prompt or starts a new request.
- Show local download, preparation, and generation progress separately.
- Surface model size and memory requirements before local download when that metadata is available.
- Treat remote usage and local performance metadata as optional.
