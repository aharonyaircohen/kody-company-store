# Bug Fix

## Job

Run the full Bug Flow end-to-end: reproduce the reported failure, plan the fix, implement it, review the pull request, then fix review findings when needed.

## Workflow

1. `reproduce` — write and commit a focused failing test that proves the bug. If the failure cannot be reproduced, record the warning and continue.
2. `plan` — produce the implementation plan from the reproduced failure or the explicit no-repro warning.
3. `run` — fix the bug using the reproduced failure artifact, run verification, and open or update the pull request.
4. `review` — review the pull request.
5. `fix` — run only when review reports concerns or a blocking failure.

## Output

A verified fix branch and pull request linked to the source issue.

## Allowed Commands

- Run the `bug` workflow.

## Restrictions

- Only run after an explicit issue dispatch.
- Prove or explain the failure before claiming the fix is complete.
- Do not broaden the work beyond the reported bug.
