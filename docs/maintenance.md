# Maintenance

This repo is a shared asset store with a small test harness for Store-owned
contracts. Treat changes as contract changes for every consumer that resolves
assets from the store.

## Safe Edit Flow

1. Identify the asset kind and slug.
2. Read the existing asset files and the matching manifest entry.
3. Confirm this is the canonical shared default for the slug.
4. Edit only the shared default behavior that belongs in the store.
5. Keep consumer-specific state in the consumer repo.
6. Validate JSON before committing.
7. Review the diff for accidental runtime state, secrets, or local paths.

## Stable Curation

`stable` should publish one shared default per slug. When several repos have
same-name variants, do not add them all under the same slug.

Choose one:

- Publish the safest company-wide default under the existing slug.
- Keep repo-only behavior as a local `.kody` override in that consumer repo.
- Rename repeated variants with explicit slugs such as `qa-web` or
  `qa-dashboard`.
- Parameterize one shared asset if only inputs differ.

## JSON Checks

Validate the top-level config and manifest:

```bash
jq empty kody-store.json .kody/store-manifest.json
```

Validate all asset profiles:

```bash
find .kody -name profile.json -print0 | xargs -0 -n1 jq empty
```

Validate CMS examples:

```bash
node cms/bin/cms.mjs validate cms/examples/kody-state/A-Guy-Admin/cms
```

Run Store contract tests:

```bash
npm test
```

## Diff Review

Useful paths to review before committing:

```bash
git diff -- README.md docs/ kody-store.json .kody/
```

Look especially for:

- Secrets or tokens.
- `.kody/agent-runs/` or `.kody/sessions/` files.
- Absolute local paths added to capability behavior.
- Agent identity files that define job-specific commands instead of identity.
- Capabilities referencing unavailable scripts or CLI tools.

## Adding A Shared Asset

Use the existing layout for the asset kind:

- Capability: `.kody/capabilities/<slug>/profile.json`, plus `capability.md`.
- Command: `.kody/commands/<slug>.md`.
- Goal template: `.kody/goals/templates/<slug>/state.json`.
- Agent: `.kody/agents/<slug>.md`.
- CMS adapter: `cms/contract`, `cms/adapters/<adapter>`, plus focused tests.

Choose stable slugs. Renaming a slug is a breaking change for consumers that
reference it from capabilities, scripts, or dashboards.

Store capabilities and goals must be safe as inactive catalog entries. Do not
add `disabled: true` to all shared capabilities; activation belongs in the
consumer repo's `kody.config.json`. Store goal templates should start with
`state: "inactive"`.

See [activation.md](activation.md) for the full activation contract.

## Updating The Manifest

The manifest is generated provenance from the import process. If an asset came
from a bulk import or duplicate-resolution pass, update `.kody/store-manifest.json`
and `docs/import-summary.md` together so they describe the same store snapshot.

For hand edits to an existing asset, update the manifest only if the provenance,
hash, duplicate metadata, or selected source changed.
