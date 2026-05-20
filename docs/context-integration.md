# Context Integration

There are two supported context patterns.

## Pattern 1, App-Owned Context

Apps may gather their own context and pass it to yLLMKit as messages.

```text
User asks question
  ↓
App gathers context from its own database, documents, or services
  ↓
App formats context into messages
  ↓
yLLMKit provider generates answer
```

This remains valid.

## Pattern 2, yLLMKitContext

Apps may use `yLLMKitContext` for text/chat memory, document chunking, hierarchical summaries, and prompt budgeting.

```text
Conversation transcript and/or text documents
  ↓
yLLMKitContext stores raw source text
  ↓
yLLMKitContext chunks and summarizes derived context
  ↓
yLLMKitContext builds a prompt-ready context package
  ↓
yLLMKit provider generates answer
```

## Source of Truth

Raw transcript and raw source text remain authoritative.

Summaries, chunks, snapshots, and prepared contexts are derived artifacts.

If a compressed summary conflicts with raw source, raw source wins.

## Local-First Value Proposition

When external LLM tokens are expensive or limited, developers can use a local model through `yLLMKitMLX` to maintain summaries and context snapshots.

That lets the final external model receive fewer repeated tokens and more high-value context.

Example:

```text
Local MLX model:
  summarize, chunk, maintain context

Remote provider:
  answer final user request with optimized context
```

## Developer Control

Developers choose which provider performs context processing.

Allowed:

- Local model for summarization, remote model for final answer.
- Remote cheaper model for summarization, premium model for final answer.
- Same model for summarization and final answer.
- Deterministic-only chunking with no model summarization.
- App-supplied summaries.

## Full-Book-Sized Text

Apps may pass full-book-sized text into `yLLMKitContext`.

The context layer should chunk by estimated tokens, not message count.

For oversized messages or documents, the context layer should split within a message or document while preserving source references.

## Data Changes

If a model response proposes changing app data, treat the response as a proposal.

```text
LLM proposes update
  ↓
App shows diff or preview
  ↓
User accepts, edits, or rejects
  ↓
App updates its database
```

Do not let yLLMKit or yLLMKitContext directly mutate app-owned source-of-truth data.
