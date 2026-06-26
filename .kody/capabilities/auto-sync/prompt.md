# Auto Sync

Deterministic agentAction. `tick.sh` scans open non-draft mergeable PRs, checks branch behind counts, posts `@kody sync` or stuck comments when not in dry-run mode, and emits the next agentResponsibility state block.
