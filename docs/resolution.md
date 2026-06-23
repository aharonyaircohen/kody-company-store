# Resolution

Kody store assets are shared defaults. Local repo assets are overrides.

Resolution order:

1. Local `.kody/agent-responsibilities/<slug>`, `.kody/agent-actions/<slug>`,
   `.kody/commands/<slug>.md`, `.kody/goals/templates/<slug>/state.json`, or
   `.kody/agents/<slug>.md`
2. Store `.kody/agent-responsibilities/<slug>`, `.kody/agent-actions/<slug>`,
   `.kody/commands/<slug>.md`, `.kody/goals/templates/<slug>/state.json`, or
   `.kody/agents/<slug>.md`
3. Engine built-ins

Resolution makes an asset available. Activation decides whether it runs.

See [activation.md](activation.md) for the full activation contract.

## Activation

Consumer repos activate store agentResponsibilities and goals in `kody.config.json`:

```json
{
  "company": {
    "activeAgentResponsibilities": ["release"],
    "activeGoals": ["web-release"]
  }
}
```

Missing or empty activation lists mean no store agentResponsibilities or goals auto-run. Local
repo agentResponsibilities and goals remain repo-owned.

## Store Scope

The store does not own repo-specific state, runs, sessions, secrets, reports,
goal runtime history, task state, or one-off local scripts.
