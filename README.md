# Kody Store

Shared Kody assets for Kody engine consumer repos.

This repo is the central catalog of reusable `.kody` assets. Consumer repos keep
repo-specific assets locally and use this store as the shared default layer.

## What's Here

- `kody-store.json` defines store name, layout version, default ref, asset roots, and resolution order.
- `.kody/duties/` contains shared duty definitions.
- `.kody/executables/` contains shared executable definitions, prompts, and supporting scripts.
- `.kody/goals/templates/` contains shared managed goal templates.
- `.kody/staff/` contains shared staff personas.
- `.kody/store-manifest.json` records imported asset provenance.
- `docs/` contains store contract and maintenance notes.

## Resolution

Kody resolves assets in order:

1. Consumer-local `.kody` assets
2. Store assets
3. Engine built-ins

Local assets override store assets with the same slug. Store assets are shared
defaults, not repo-specific runtime state.

## Activation

The store is a catalog, not an auto-run list.

See [docs/activation.md](docs/activation.md) for the full activation contract.

Consumer repos decide which shared duties and goals are active:

```json
{
  "company": {
    "activeDuties": ["release"],
    "activeGoals": ["web-release"]
  }
}
```

Store duties and goals are inactive by default. A duty may declare `every`, but
that cadence is only used after the consumer activates the duty. A store goal is
a reusable template until the consumer activates it and supplies repo facts.
Scheduled goal activation uses object form, such as
`{ "template": "web-release", "every": "1w" }`, to create one runtime instance
per time bucket on the consumer repo's `kody-state` branch.

## Asset Kinds

- `duties`: scheduled or callable work definitions under `.kody/duties/<slug>/`
- `executables`: runnable agent/tool definitions under `.kody/executables/<slug>/`
- `goals`: managed objective templates under `.kody/goals/templates/<slug>/state.json`
- `staff`: persona files under `.kody/staff/<slug>.md`

## What Does Not Belong Here

Do not commit consumer-specific runtime state to the store. That includes runs,
sessions, secrets, reports, goal runtime history, local task state, and generated
working files.

## Maintenance

This repo has no app build or package command. It is a versioned asset store.
Before changing shared assets, read [docs/maintenance.md](docs/maintenance.md)
and validate edited JSON.

The current default branch/ref is `stable`.
