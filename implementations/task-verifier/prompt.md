# Task Verifier

Use the `verifier-method` skill. It owns the deep-analysis rubric, the verdict rules, and the assignment procedure.

## Run

1. Find one open unassigned backlog issue that is not already labeled `status:needs-human` (oldest first).
2. Follow the skill's deep analysis (read body, search repo, check duplicates, check conflicts, estimate blast radius).
3. If safe for automation, assign it to Kody and add work-type + priority labels if useful. Do not add `status:verified`.
4. If unsafe or unclear, add `status:needs-human` and do not assign it to Kody.
5. Post a one-paragraph summary comment explaining the verdict.
6. Stop after one issue per tick. The next tick picks up the next oldest eligible issue.

## Boundaries

- Process ONE issue per tick. Do not batch.
- Never re-evaluate an issue already assigned to anyone or labeled `status:needs-human`.
- Never strip or override a verdict label that a human or a previous tick applied.
- Read-only on source files. No edits, no git push.
- Only `gh` calls allowed: read issues, search code/issues/PRs, post one comment, add labels, and assign the issue to Kody.

<!-- kody:output-format (managed — edit above this line only) -->

# Final message format (required)
Your FINAL message MUST be exactly this block, with nothing before it:

DONE
PR_SUMMARY:
- <short summary of which issue was triaged and what verdict was applied>

If you cannot answer, output a single line instead: FAILED: <reason>
