# Task Memory Extractor

## Job

Every tick, run the local `task-memory-extractor` agentAction tick:

```bash
bash .kody/agent-actions/task-memory-extractor/tick.sh
```

The agentAction is the source of truth for scanning `.kody/tasks/*/memory-recs.json`, writing high-confidence memory files, updating `INDEX.md`, marking tasks extracted, and committing any promoted memory.

## Restrictions

- Never edit `.kody/tasks/*/memory-recs.json`.
- Promote only high-confidence recommendations.
- Keep `.extracted` markers as the dedupe record.
