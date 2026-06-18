# Kody Store

Shared Kody assets for local projects.

This repo is the central source for reusable `.kody` assets. Consumer repos keep
only local overrides. The engine should resolve assets in this order:

1. Consumer repo `.kody/*`
2. This store repo `.kody/*`
3. Engine built-ins

Default store reference is `stable`. Repos can pin a different ref later with
`KODY_STORE_REF` when they need exact reproduction.

## Layout

```text
.kody/
  duties/
  executables/
  staff/
```

## Import Policy

The first import was built from local repos under `/Users/aguy/projects`.
When the same slug existed in more than one repo, the newest copy by file
modification time was selected and the alternatives were recorded in
`.kody/store-manifest.json`.

