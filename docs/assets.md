# Assets

Kody store assets live under the roots declared in `kody-store.json`.

```json
{
  "assetRoots": {
    "duties": ".kody/duties",
    "executables": ".kody/executables",
    "staff": ".kody/staff"
  }
}
```

The slug is the lookup key. For directory-backed assets, the slug is the
directory name. For staff, the slug is the filename without `.md`.

## Duties

Path:

```text
.kody/duties/<slug>/
```

Common files:

- `profile.json`: duty metadata, cadence, runner, mentions, and executable link.
- `duty.md`: human-readable duty instructions when the duty needs them.

Common `profile.json` fields:

- `name`: should match the directory slug.
- `describe`: short description shown to operators or agents.
- `every`: optional schedule cadence, such as `1d`.
- `runner`: staff persona slug.
- `mentions`: optional GitHub/user mentions for reports.
- `executable`: executable slug to run for this duty.

## Executables

Path:

```text
.kody/executables/<slug>/
```

Common files:

- `profile.json`: executable metadata and runtime contract.
- `prompt.md`: prompt used by the executable.
- `persona.md`: optional executable-specific persona context.
- `*.sh`: optional helper scripts used by the executable.

Common `profile.json` fields:

- `name`: should match the directory slug.
- `role`: executable role, for example `primitive`.
- `kind`: execution kind, for example `oneshot`.
- `describe`: short description of what the executable does.
- `inputs`: expected input names.
- `claudeCode`: model, permissions, tool, hook, skill, command, and MCP settings.
- `cliTools`: external CLI tools the executable expects.
- `scripts`: preflight and postflight script hooks.
- `output`: expected output action types.

Executable scripts should consume environment variables or files provided by the
runtime. They should not own consumer secrets or decrypt repo-local vaults
inside this store.

## Staff

Path:

```text
.kody/staff/<slug>.md
```

Staff files are personas. They describe identity, voice, and operating style.
Concrete job behavior should live in duties and executables, not in persona
files.

## Manifest

`.kody/store-manifest.json` is import provenance. It records:

- `generatedAt`: when the manifest was generated.
- `projectsRoot`: source project root used during import.
- `storeRoot`: destination store root.
- `selection`: duplicate resolution strategy.
- `kinds`: selected assets and duplicate metadata for duties, executables, and
  staff.

The current selection strategy is `newest-file-mtime-per-kind-and-slug`.
When duplicate slugs exist across imported projects, the newest file mtime won.

That strategy documents the bootstrap import only. Do not use newest mtime as
the ongoing `stable` publishing rule. `stable` should keep one curated shared
default per slug; repo-specific or repeated variants should be local overrides
or renamed assets.
