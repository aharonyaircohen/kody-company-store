# PR Health Triage

## Job

Review open PRs for conflicts, failed CI, or stale branches, then recommend the next safe repair.

## Implementation

Run the `pr-health-triage` implementation. Its skill owns the detailed method and runtime state handling.

## Output

A PR repair recommendation.

## Allowed Commands

- Run the `pr-health-triage` implementation.

## Restrictions

- Only `fix-ci`, `sync`, or `resolve` repairs are in scope.
- One repair comment per PR per tick.
- Never merge, close, approve, relabel, edit files, or dispatch a repair.
- This capability is advisory-only; operator confirmation triggers the repair.
