# Chore Implementation

## Job

Run the Chore Flow end-to-end: complete the scoped maintenance change, review the pull request, then fix review findings when needed.

## Workflow

1. `run` — complete the scoped chore, verify it, and open or update the pull request.
2. `review` — review the pull request.
3. `fix` — run only when review reports concerns or a blocking failure.

## Output

A verified maintenance change or a clear no-change result.

## Allowed Commands

- Run the `chore` workflow.

## Restrictions

- Keep the work mechanical and scoped.
- Do not introduce unrelated product changes.
- Verify the relevant checks before completion.
