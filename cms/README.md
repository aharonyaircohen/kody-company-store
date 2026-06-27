# Kody CMS Adapters

Phase 1 CMS support lives here as a Store-owned, generic adapter contract.

The contract keeps ownership separate:

- Store owns the reusable adapter code.
- A state repo owns CMS configuration.
- The consumer database or repository owns content data.
- Kody owns the operator workflow.

## Layout

```text
cms/
  contract/           # config, validation, operations
  adapters/
    mongodb/          # generic MongoDB collection adapter
    github/           # generic GitHub file-backed adapter
    file/             # generic local JSON file adapter
  examples/
    kody-state/       # example state-repo config layout
  tests/              # node:test coverage
```

## State Repo Config

For A-Guy Admin the canonical state path is:

```text
A-Guy-Admin/cms/
  config.json
  collections/
    lessons.json
  environments/
    dev.json
```

No secret values belong in CMS config. Environment files name a secret, such as
`A_GUY_DEV_MONGODB_URI`, and the runtime resolves it from the repo vault.

## Safety Defaults

- `list`, `get`, and `search` are read operations.
- `create` and `update` require approval unless config explicitly enables them.
- `delete` is disabled by default.
- File-backed adapters create missing folders/files on first write. GitHub
  creates the missing JSON path through the Contents API.
- Schema changes are not applied by these adapters in Phase 1.
