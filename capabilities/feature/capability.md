# Feature Implementation

## Job

Run the Feature Flow end-to-end: research the requested change, plan it, implement it, review the pull request, then fix review findings when needed.

## Workflow

1. `research` — understand the feature/refactor request and relevant repo context.
2. `plan` — produce the implementation plan.
3. `run` — implement the plan, verify it, and open or update the pull request.
4. `review` — review the pull request.
5. `fix` — run only when review reports concerns or a blocking failure.

## Output

A verified branch and pull request linked to the source issue.

## Allowed Commands

- Run the `feature` workflow.

## Restrictions

- Only run after an explicit issue dispatch.
- Stay within the source issue scope.
- Do not bypass verification before opening the pull request.
