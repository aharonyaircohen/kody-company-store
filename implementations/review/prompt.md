Review PR #{{pr.number}} and write one structured review comment. Do not edit files or run git/gh write commands.

Use the `code-review` skill.

# PR #{{pr.number}}: {{pr.title}}

Base: {{pr.baseRefName}} <- Head: {{pr.headRefName}}

{{pr.body}}

{{conventionsBlock}}

# Diff

```diff
{{prDiff}}
```

# Run

- Follow the `code-review` skill.
- Use specialist reviewer subagents in parallel as described by the skill.
- Paste relevant hunks from the supplied diff into every child prompt. Do not
  merely tell a child that the parent has the diff.
- Read only.
- Do not invent citations or pass blocked reviewer dimensions as clean.
- Verify all warnings and blockers before including them in the final comment.
- A final concern must start with `- **[WARN]**` or `- **[BLOCK]**`. If you
  cannot justify either severity, discard it.
- Discard exact-current-value ratchets, metadata or documentation tag typos,
  format-only changes to pre-existing casts, follow-up ideas, and clean-axis
  commentary. These are not review findings without a new behavioral risk.
- When every verified reviewer result is `NONE`, return `PASS`; do not invent a
  concern to make the review look substantive.

# Final response (required)

Return exactly the raw markdown review comment defined in the `code-review`
skill. Its first line must be `## Verdict: PASS`, `## Verdict: CONCERNS`, or
`## Verdict: FAIL`. Do not wrap it in `DONE`, `COMMIT_MSG`, or `PR_SUMMARY`.
Use only `### Summary`, `### Concerns`, and `### Bottom line`. Do not include
notes, clean axes, strengths, suggestions, follow-ups, or nits.
