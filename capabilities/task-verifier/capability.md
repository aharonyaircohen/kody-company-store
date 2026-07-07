# Task Verifier

## Job

Scan the backlog every tick. For one open unassigned issue, run deep analysis: read the body, search the repo for keywords and duplicates, check for conflicts with existing patterns, and estimate blast radius. If safe for Kody, assign the issue to Kody and add a work-type label plus a `priority:*` label if useful. If a human must look first, add `status:needs-human`. Post a one-paragraph summary comment explaining the verdict.

## Implementation

Run the `task-verifier` implementation. Its skills and scripts own the implementation details.

## Allowed Commands

- `gh issue list`
- `gh issue view`
- `gh issue edit`
- `gh issue comment`
- `gh search issues`
- `gh search prs`
- read-only local search commands

## Restrictions

- Stay within the capability's purpose and the per-implementation rules.
- Do not perform actions outside the contract defined by this capability.
- Process ONE issue per tick. Do not batch.
- Never re-evaluate an issue already assigned to anyone or labeled `status:needs-human`.
- Never strip or override a verdict label that a human or a previous tick applied.
- Read-only on source files. No edits, no git push.
