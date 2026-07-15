# Kody Store

Shared Kody assets for Kody engine consumer repos. This repo is the central catalog for reusable Kody assets. Consumer repos keep repo-specific assets in their configured state repo and use the store as the shared default layer.

## What's Here

- `kody-store.json` defines store name, layout version, default ref, asset roots, and resolution order.
- `capabilities/` contains canonical shared capabilities (`profile.json` + `capability.md`).
- `commands/` contains shared Dashboard slash commands.
- `workflows/` contains ordered capability stacks (`workflow.json`).
- `goals/templates/` contains shared agentGoal and agentLoop templates.
- `agents/` contains shared agent identity identities.
- `cms/` contains generic CMS contracts, adapters, examples, and tests.
- `store-manifest.json` records imported asset provenance.
- `docs/` contains store contract and maintenance notes.
- `docs/ai-agency-health-matrix.md` defines the repo-local agency health report contract.
- `docs/model-creators.md` defines the seven detailed, agency-owned model creation contracts.

## Resolution

Kody resolves assets in order:

1. Consumer-local hydrated `.kody` assets
2. Store assets
3. Engine built-ins

Local assets override store assets with the same slug. Store assets are shared defaults, not repo-specific runtime state.

## Activation

The store is a catalog, not an auto-run list. Consumer repos decide which shared company model is active:

```json
{
  "company": {
    "activeCapabilities": ["fix-ci", "review"],
    "activeGoals": ["task-delivery", "prs-stay-mergeable", "ci-health", "product-quality", "ai-agency-health"]
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
See [docs/ai-agency-health-matrix.md](docs/ai-agency-health-matrix.md) for the
AI Agency health report model.
See [docs/architecture-boundaries.md](docs/architecture-boundaries.md) for the
goal, loop, capability, and implementation ownership rules.
See [docs/model-creators.md](docs/model-creators.md) for model creation and
cross-model coordination rules.

## Architecture Boundaries

Store assets must keep responsibilities separate:

- Goals and loops own durable progress, schedule, evidence, blockers, and
  completion decisions.
- Capabilities own reusable abilities: observe, act, or verify.
- Implementation profiles own one runnable action and return facts, evidence,
  artifacts, blockers, and status.
- The runner that invoked a capability owns the parent goal or loop context and
  attaches capability output to that parent.

Do not make a normal capability require its parent goal id, route, stage, or
destination outcome. Existing `--goal` inputs and target-bearing reports are
compatibility paths only.

## Asset Kinds

- `capabilities`: canonical reusable capabilities under `capabilities/<slug>/`
- `commands`: Dashboard slash command templates under `commands/<slug>.md`
- `goals`: managed agentGoal and agentLoop templates under `goals/templates/<slug>/state.json`
- `workflows`: ordered capability stacks under `workflows/<slug>/workflow.json`
- `agent`: agent identity files under `agents/<slug>.md`
- `cms`: generic CMS adapter contracts and implementations under `cms/`

## What Does Not Belong Here

Do not commit consumer-specific runtime state to the store. This includes runs, sessions, secrets, reports, goal runtime history, local task state, and generated working files.

## Maintenance

This repo is a versioned asset store with a small test harness for Store-owned contracts. Before changing shared assets, read [docs/maintenance.md](docs/maintenance.md), validate edited JSON, and run the relevant tests. The current default branch/ref is `stable`.
