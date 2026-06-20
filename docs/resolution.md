# Resolution

Kody store assets are shared defaults. Local repo assets are overrides.

Resolution order:

1. Local `.kody/duties/<slug>`, `.kody/executables/<slug>`,
   `.kody/goals/<slug>/state.json`, or `.kody/staff/<slug>.md`
2. Store `.kody/duties/<slug>`, `.kody/executables/<slug>`,
   `.kody/goals/<slug>/state.json`, or `.kody/staff/<slug>.md`
3. Engine built-ins

Resolution makes an asset available. Activation decides whether it runs.

## Activation

Consumer repos activate store duties and goals in `kody.config.json`:

```json
{
  "company": {
    "activeDuties": ["release"],
    "activeGoals": ["web-release"]
  }
}
```

Missing or empty activation lists mean no store duties or goals auto-run. Local
repo duties and goals remain repo-owned.

## Store Scope

The store does not own repo-specific state, runs, sessions, secrets, reports,
goal runtime history, task state, or one-off local scripts.
