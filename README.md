# Kody Store

Shared Kody assets for Kody engine consumer repos. This repo is the central catalog for reusable `.kody` assets. Consumer repos keep repo-specific assets locally and use the store as the shared default layer.

## What's Here

- `kody-store.json` defines store name, layout version, default ref, asset roots, and resolution order.
- `.kody/agent-responsibilities/` contains shared agentResponsibility definitions.
- `.kody/agent-actions/` contains shared agentAction definitions, prompts, and supporting scripts.
- `.kody/goals/templates/` contains shared agentGoal and agentLoop templates.
- `.kody/agents/` contains shared agent identity identities.
- `.kody/store-manifest.json` records imported asset provenance.
- `docs/` contains store contract and maintenance notes.

## Resolution

Kody resolves assets in order:

1. Consumer-local `.kody` assets
2. Store assets
3. Engine built-ins

Local assets override store assets with the same slug. Store assets are shared defaults, not repo-specific runtime state.

## Activation

The store is a catalog, not an auto-run list. Consumer repos decide which shared company model is active:

```json
{
  "company": {
    "activeGoals": ["prs-stay-mergeable", "product-quality"]
  }
}
```

Scheduled company behavior should be activated through agentLoops. A agentResponsibility may declare `every`, but the active agentLoop tick decides whether that agentResponsibility is due, skipped, blocked, or selected. A store template is reusable until a consumer activates it or supplies repo facts. String activation creates one stable agentLoop instance from the matching template. Scheduled activation uses object form, `{ "template": "release-safety", "every": "1w" }`, to create one runtime instance per time bucket on the consumer repo's `kody-state` branch.

See [docs/activation.md](docs/activation.md) for the full activation contract.

## Asset Kinds

- `agentResponsibilities`: available responsibilities and command wrappers under `.kody/agent-responsibilities/<slug>/`
- `agentActions`: runnable agent/tool definitions under `.kody/agent-actions/<slug>/`
- `goals`: managed agentGoal and agentLoop templates under `.kody/goals/templates/<slug>/state.json`
- `agent`: agent identity files under `.kody/agents/<slug>.md`

## What Does Not Belong Here

Do not commit consumer-specific runtime state to the store. This includes runs, sessions, secrets, reports, goal runtime history, local task state, and generated working files.

## Maintenance

This repo has no app build package command. It is a versioned asset store. Before changing shared assets, read [docs/maintenance.md](docs/maintenance.md) and validate edited JSON. The current default branch/ref is `stable`.
