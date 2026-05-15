# Context Integration

yLLMKit does not require a specific database, search engine, file format, or UI framework.

Your app is responsible for collecting the information it wants the model to use. That context can come from user input, documents, search results, notes, records, forms, logs, web content, or any other app-owned source.

## Expected Pattern

```text
User asks question
  ↓
App decides what context is needed
  ↓
App gathers relevant text or structured context
  ↓
App formats context into messages
  ↓
yLLMKit generates answer
  ↓
App displays the answer or proposed action
```

## Example Context-Backed Prompt

```swift
let context = """
CONTEXT:
1. The app imports transactions from CSV files.
2. Duplicate transactions are detected by matching date, amount, and description.
3. The user can review duplicates before deleting anything.

TASK:
Explain how duplicate detection works in plain language.
"""

let messages = [
    LLMMessage(
        role: .system,
        content: "Use the supplied context. Say when the context is insufficient."
    ),
    LLMMessage(role: .user, content: context)
]
```

## Integration Guidance

- Keep retrieval and ranking logic in your app.
- Keep app data models in your app.
- Pass the final context to yLLMKit as `LLMMessage` values.
- Use message metadata for lightweight labels such as document IDs, section names, or request IDs.
- Let your UI decide how often to render streamed tokens.

## Data Changes

If a model response proposes changing app data, treat the response as a proposal. Let the user review, accept, edit, or reject the change before your app writes anything.

```text
LLM proposes update
  ↓
App shows diff
  ↓
User accepts, edits, or rejects
  ↓
App updates database
```
