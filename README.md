# Kody Store

Shared Kody assets for local projects and Kody engine consumers.

This repo is the central source for reusable `.kody` assets. Consumer repos keep
repo-specific assets locally and use this store as the shared default layer.

## What Is Here

- `kody-store.json` defines the store name, layout version, default ref, asset
  roots, and resolution order.
- `.kody/duties/` contains shared duty definitions.
- `.kody/executables/` contains shared executable definitions, prompts, and
  supporting scripts.
- `.kody/goals/` contains shared managed goal definitions.
- `.kody/staff/` contains shared staff personas.
- `.kody/store-manifest.json` records where imported assets came from and which
  duplicate slug won during import.
- `docs/` contains the store contract and maintenance notes.

## Resolution Model

Kody should resolve assets in this order:

1. Consumer-local `.kody` assets
2. Store assets from this repo
3. Engine built-ins

That means a consumer repo can override a shared asset by defining the same slug
locally. Store assets are defaults, not repo-specific state.

See [docs/resolution.md](docs/resolution.md) for the detailed rules.

## Stable Policy

`stable` is the default company-store ref. It should contain one canonical
shared asset per slug.

If several repos have variants with the same slug, publish the safest
company-wide default under that slug. Keep one-off differences local in the
consumer repo. Repeated variants should get explicit names such as `qa-web`,
`qa-dashboard`, or `release-dashboard`.

## Asset Kinds

The store currently publishes four asset kinds:

- `duties`: scheduled or callable work definitions under `.kody/duties/<slug>/`
- `executables`: runnable agent/tool definitions under `.kody/executables/<slug>/`
- `goals`: managed objective definitions under `.kody/goals/<slug>/state.json`
- `staff`: persona files under `.kody/staff/<slug>.md`

See [docs/assets.md](docs/assets.md) for expected file layout and field
guidance.

## What Does Not Belong Here

Do not commit consumer-specific runtime state to the store. That includes runs,
sessions, secrets, reports, goal runtime history, local task state, or generated
working files.

The `.gitignore` already excludes `.kody/runs/` and `.kody/sessions/`.

## Maintenance

This repo has no app build or package command. It is a versioned asset store.
Before changing shared assets, read [docs/maintenance.md](docs/maintenance.md)
and validate edited JSON.

The current default branch/ref is `stable`.

## Layout

```text
.kody/
  duties/
  executables/
  goals/
  staff/
```

## Import Policy

The first import was built from local repos under `/Users/aguy/projects`.
When the same slug existed in more than one repo, the newest copy by file
modification time was selected and the alternatives were recorded in
`.kody/store-manifest.json`.

That newest-copy rule was only bootstrap convenience. Long-term `stable`
publishing should be curated: one shared default per slug, variants renamed or
left local.
