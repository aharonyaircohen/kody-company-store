# Redispatch

## Job

Every tick, run the local `redispatch` agentAction tick:

```bash
bash .kody/agent-actions/redispatch/tick.sh
```

The agentAction is the source of truth for stalled issue detection, dry-run logging, live-test gating, labels, comments, and next-state output.

## Restrictions

- Dry-run mode is controlled inside `.kody/agent-actions/redispatch/tick.sh`.
- Exclude `kody:stuck`, `kody:no-redispatch`, and `kody:stalled`.
- Do not resume an issue more than once per UTC day.
- Keep state in `.kody/agent-responsibilities/redispatch.state.json`.
