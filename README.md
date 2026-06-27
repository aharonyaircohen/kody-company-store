# Kody Store

Shared Kody assets for Kody engine consumer repos. This repo is the central catalog for reusable `.kody` assets. Consumer repos keep repo-specific assets locally and use the store as the shared default layer.

## What's Here

- `kody-store.json` defines store name, layout version, default ref, asset roots, and resolution order.
- `.kody/capabilities/` contains canonical shared capabilities (`profile.json` + `capability.md`).
- `.kody/commands/` contains shared Dashboard slash commands.
- `.kody/goals/templates/` contains shared agentGoal and agentLoop templates.
- `.kody/agents/` contains shared agent identity identities.
- `cms/` contains generic CMS contracts, adapters, examples, and tests.
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
    "activeCapabilities": ["fix-ci", "review"],
    "activeGoals": ["prs-stay-mergeable", "ci-health", "product-quality", "ai-agency-health"]
  }
}
```

Capabilities are available abilities; activation decides whether a shared one is
enabled for the consumer repo. Scheduled company behavior should usually be
activated through agentGoals or agentLoops. A store template is reusable until a
consumer activates it or supplies repo facts. String activation creates one
stable agentLoop instance from the matching template. Scheduled activation uses
object form, `{ "template": "release-safety", "every": "1w" }`, to create one
runtime instance per time bucket in the configured state repo.

See [docs/activation.md](docs/activation.md) for the full activation contract.

## Asset Kinds

- `capabilities`: canonical reusable capabilities under `.kody/capabilities/<slug>/`
- `commands`: Dashboard slash command templates under `.kody/commands/<slug>.md`
- `goals`: managed agentGoal and agentLoop templates under `.kody/goals/templates/<slug>/state.json`
- `agent`: agent identity files under `.kody/agents/<slug>.md`
- `cms`: generic CMS adapter contracts and implementations under `cms/`

## What Does Not Belong Here

Do not commit consumer-specific runtime state to the store. This includes runs, sessions, secrets, reports, goal runtime history, local task state, and generated working files.

## Maintenance

This repo is a versioned asset store with a small test harness for Store-owned contracts. Before changing shared assets, read [docs/maintenance.md](docs/maintenance.md), validate edited JSON, and run the relevant tests. The current default branch/ref is `stable`.
