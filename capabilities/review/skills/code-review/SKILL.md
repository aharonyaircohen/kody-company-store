# Code Review

Use this skill to review a PR and produce one structured markdown review
comment.

## Workflow

1. Run all four reviewers in a single parallel dispatch on every PR:
   - `review-security`.
   - `review-reliability`.
   - `review-maintainability`.
   - `review-complexity`.
2. In the single dispatch, paste the relevant diff hunks directly into each child prompt,
   together with PR context and base/head refs. A reference to the supplied diff is not
   sufficient because child context is isolated. Tell them not to fetch the PR or full
   diff again. Require targeted changed-file reads before reporting.
3. Check each reviewer status. `NEEDS_CONTEXT` is not a clean pass.
4. Verify every `WARN` and `BLOCK` against the diff and nearby code. Discard
   speculative, pre-existing, and process-only findings. Merge duplicates,
   keeping the strongest supported severity and clearest evidence.
   Discard `NIT`, `NOTE`, and `NONE` items rather than turning them into final
   concerns. Never report PR title, scope, commit splitting, or bisectability;
   those are process preferences, not code findings.
5. Return at most five verified concerns in the combined comment, ordered by
   severity and impact. If the recommended action is a follow-up rather than a
   current `WARN` or `BLOCK`, discard it.
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
- A strict ratchet whose cap equals the current measured value is intended to
  prevent regression; that fact alone is not a finding. Report a ratchet only
  when it is misconfigured, bypassable, or weakened.
- A single caller or extraction is not by itself a complexity finding. Require
  demonstrated indirection or change cost and a simpler correct alternative.
- Package-boundary glue or duplication is not automatically a maintainability
  issue. Require evidence of behavioral drift, inconsistent ownership, or
  material future change cost.
- A named extraction from a large component is normally a maintainability
  improvement, even with one caller. Do not infer a bad motive from a size
  ratchet or an extraction-oriented docstring; require a concrete regression.
- Tiny package-local test setup duplicated across packages is not a finding.
  Do not propose a shared package unless substantial logic has already drifted.

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

### Concerns
- <bullet with file:line, or "None">

### Bottom line
<one sentence>
```

Do not wrap the review in `DONE`, `COMMIT_MSG`, or `PR_SUMMARY`.
