# Auto Resolve

Deterministic agentAction. `tick.sh` scans open non-draft conflicting PRs, posts `@kody resolve` or stuck comments when not in dry-run mode, and emits the next agentResponsibility state block.
