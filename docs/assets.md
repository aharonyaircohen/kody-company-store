# Assets

Kody store assets live under roots declared in `kody-store.json`.

```json
{
  "assetRoots": {
    "duties": ".kody/duties",
    "executables": ".kody/executables",
    "goals": ".kody/goals",
    "staff": ".kody/staff"
  }
}
```

The slug is the lookup key.

## Duties

Path:

```text
.kody/duties/<slug>/
```

Common files:

- `profile.json`: duty metadata, cadence, staff, mentions, and executable link.
- `duty.md`: human-readable duty instructions.

Store duties are inactive by default. `every` is a suggested cadence, not
permission to run in every repo. A consumer activates store duties in
`kody.config.json`:

```json
{ "company": { "activeDuties": ["release"] } }
```

## Executables

Path:

```text
.kody/executables/<slug>/
```

Common files:

- `profile.json`: executable metadata and runtime contract.
- `prompt.md`: prompt used by the executable.
- `*.sh`: optional helper scripts.

Executable scripts should consume environment variables provided by the runtime.
They should not own consumer secrets or decrypt repo-local vaults inside store.

## Staff

Path:

```text
.kody/staff/<slug>.md
```

Staff files are personas. Concrete job behavior should live in duties and
executables, not in persona files.

## Goals

Path:

```text
.kody/goals/<slug>/state.json
```

Goals are managed objective templates. A shared goal should be portable enough
for a consumer repo to activate as a starting state, then fill runtime facts such
as the release issue number.

Store goal templates should use `state: "inactive"`. Consumer runtime instances
become `active`.

Store goals are inactive by default. A consumer activates store goals in
`kody.config.json`:

```json
{ "company": { "activeGoals": ["web-release"] } }
```

Shared store goals must not contain consumer secrets, run logs, or completed
runtime history.
