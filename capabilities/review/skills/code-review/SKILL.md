# Code Review

Use this skill to review a PR and produce one structured markdown review
comment.

## Workflow

1. Run all four reviewers in a single parallel dispatch on every PR:
   - `review-security`.
   - `review-reliability`.
   - `review-maintainability`.
   - `review-complexity`.
2. Give each reviewer the already-provided PR context, base/head refs, and
   relevant diff. Tell them not to fetch the PR or full diff again. Require
   targeted changed-file reads before reporting.
3. Check each reviewer status. `NEEDS_CONTEXT` is not a clean pass.
4. Verify every `WARN` and `BLOCK` against the diff and nearby code. Discard
   speculative, pre-existing, and process-only findings. Merge duplicates,
   keeping the strongest supported severity and clearest evidence.
5. Return at most five verified concerns in the combined comment, ordered by
   severity and impact. Suggestions do not affect the verdict.
6. Resolve verdict from worst verified severity:
   - any `BLOCK` -> `FAIL`,
   - any `NEEDS_CONTEXT` -> `FAIL`,
   - no block but any `WARN` -> `CONCERNS`,
   - all `NONE` -> `PASS`.

## Review stance

- Default to skepticism until the code proves the change is correct.
- Cite real `file:line` evidence for every issue.
- Do not invent citations.
- Do not downgrade a blocking issue from any reviewer.
- Do not preserve a reviewer finding that the evidence disproves.
- Do not pass when an entire review dimension was blocked.
- Treat stubs/placeholders shipped against a stated requirement as failures.

## Implementation-depth ladder

For every change, check:

1. Exists: the function, route, config, or component is present.
2. Substantive: it has real logic, not a stub or echo.
3. Wired: its output is consumed where it matters.
4. Functional: it produces the right result for the issue cases.

Missing wiring is a reliability failure.

## Required output

Return raw markdown only. The first line must be `## Verdict: PASS | CONCERNS | FAIL`
with exactly one real verdict selected. Stay under 600 words. Do not add overview,
verification, notes, nits, or non-issues sections. Use only this shape:

```markdown
## Verdict: PASS | CONCERNS | FAIL

> Reviewed in parallel by specialist subagents (security · reliability · maintainability · complexity).

### Summary
<2-3 sentences>

### Strengths
- <bullet>

### Concerns
- <bullet with file:line, or "None">

### Suggestions
- <bullet with file:line where possible, or "None">

### Bottom line
<one sentence>
```

Do not wrap the review in `DONE`, `COMMIT_MSG`, or `PR_SUMMARY`.
