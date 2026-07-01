# Redispatch

## Job

Every tick, run the Store-owned `redispatch` capability tick:

```bash
bash tick.sh
```

The capability folder is the source of truth for stalled issue detection, dry-run logging, live-test gating, labels, comments, and next-state output.

## Restrictions

- Dry-run mode is controlled inside the Store `redispatch/tick.sh`.
- Exclude `kody:stuck`, `kody:no-redispatch`, and `kody:stalled`.
- Do not resume an issue more than once per UTC day.
- Keep state under `.kody/capabilities/redispatch/state.json`.
