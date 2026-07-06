# Code Health - architecture and type-debt signals

## Job

Run a weekly code-health sweep for architecture risks and TypeScript debt growth.

## Implementation

Run the `code-health` implementation. Its skills own the architecture-audit and type-debt methods.

## Output

A tracking issue or tracking-issue comment when concrete code-health findings need attention.

## Allowed Commands

- Run the `code-health` implementation.

## Restrictions

- Disabled until the operator enables this grouped watch.
- Read-only on the codebase.
- Do not run build, test, lint, or code edits directly from the capability.
- Only escalate concrete architecture or type-debt risks.
