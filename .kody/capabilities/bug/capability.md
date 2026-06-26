# Bug Fix

## Job

Run the bug workflow end-to-end: reproduce the reported failure, fix it, verify it, then open a pull request with evidence.

## Workflow

1. `reproduce` — write and commit a focused failing test that proves the bug.
2. `run` — fix the bug using the reproduced failure artifact, run verification, and open or update the pull request.

## Output

A verified fix branch and pull request linked to the source issue.

## Allowed Commands

- Run the `bug` workflow.

## Restrictions

- Only run after an explicit issue dispatch.
- Prove or explain the failure before claiming the fix is complete.
- Do not broaden the work beyond the reported bug.
