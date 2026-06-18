# Resolution

Kody store assets are shared defaults. Local repo assets are overrides.

Resolution order:

1. Local `.kody/duties/<slug>`, `.kody/executables/<slug>`, or
   `.kody/staff/<slug>.md`
2. Store `.kody/duties/<slug>`, `.kody/executables/<slug>`, or
   `.kody/staff/<slug>.md`
3. Engine built-ins

The store does not own repo-specific state, runs, sessions, secrets, reports, or
goals.

## Slugs

The slug is the stable asset key:

- Duties use `.kody/duties/<slug>/`.
- Executables use `.kody/executables/<slug>/`.
- Staff personas use `.kody/staff/<slug>.md`.

If a consumer repo defines the same slug locally, the local asset wins. This lets
one repo customize a shared duty, executable, or persona without changing the
default for every other repo.

## Stable Selection

The `stable` ref publishes one canonical shared asset per slug.

If several repos have different assets with the same name, choose the version
that is the safest company-wide default for `stable`. Do not publish multiple
same-name variants in `stable`.

Use one of these instead:

- Keep the repo-specific version local in that consumer repo.
- Rename repeated variants, for example `qa-web`, `qa-dashboard`, or
  `release-dashboard`.
- Make one shared asset configurable when behavior is the same and only inputs
  differ.

## Override Scope

Overrides are per kind. A local duty named `docs-health` overrides only the
store duty named `docs-health`. It does not automatically override the executable
named `docs-health`; that executable must also exist locally if the consumer
needs executable-specific changes.

## Store Scope

Store assets should be portable across consumers. Keep these out of the store:

- Runtime logs and run attempts.
- Session files.
- Secrets or encrypted consumer vaults.
- Generated reports.
- Repo-specific goals or task state.
- One-off local scripts that only work in a single consumer repo.

If behavior only makes sense for one repo, keep it in that repo's local `.kody`
directory.
