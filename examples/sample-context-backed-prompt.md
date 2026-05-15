# Sample Context-Backed Prompt

```text
SYSTEM:
Use only the supplied context. If the context is insufficient, say what is missing.

USER:
CONTEXT:
1. The app imports transactions from CSV files.
2. A transaction is considered a duplicate when date, amount, and description match an existing transaction.
3. Duplicate transactions are shown in a review screen before anything is deleted.

TASK:
Answer the question: How does duplicate transaction detection work?

Requirements:
- Use only the supplied context.
- Explain the workflow in plain language.
- Identify unresolved questions.
```
