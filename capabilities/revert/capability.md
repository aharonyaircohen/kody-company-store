# PR Revert

## Job

Revert a merged pull request when explicitly requested.

## Implementation

Run the `revert` implementation. The engine owns the implementation details.

## Output

A revert branch or pull request that undoes the target merge.

## Allowed Commands

- Run the `revert` implementation.

## Restrictions

- Run only on explicit revert requests.
- Treat this as destructive.
- Do not revert unrelated commits.
