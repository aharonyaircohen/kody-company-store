# Code Review

Use this skill to review a PR and produce one structured markdown review
comment.

## Workflow

1. Run all four reviewers in parallel on every PR:
   - `review-security`.
   - `review-reliability`.
   - `review-maintainability`.
   - `review-complexity`.
2. Give each reviewer the PR context, base/head refs, and diff. Require full
   changed-file reads before reporting.
3. Check each reviewer status. `NEEDS_CONTEXT` is not a clean pass.
4. Merge duplicate findings, keeping the strongest severity and clearest
   evidence, then synthesize one comment.
5. Resolve verdict from worst severity:
   - any `BLOCK` -> `FAIL`,
   - any `NEEDS_CONTEXT` -> `FAIL`,
   - no block but any `WARN` -> `CONCERNS`,
   - all `NONE` -> `PASS`.

## Review stance

- Default to skepticism until the code proves the change is correct.
- Cite real `file:line` evidence for every issue.
- Do not invent citations.
- Do not downgrade a blocking issue from any reviewer.
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

Return raw markdown only, with this shape:

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
