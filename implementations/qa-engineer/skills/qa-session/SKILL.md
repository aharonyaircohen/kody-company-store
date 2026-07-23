# QA Session

Use this skill to browse a running app like a user and produce one structured
QA report.

## Workflow

1. Navigate to the target base URL first. If unreachable, stop browsing and
   report the reachability gap.
2. Build a short test matrix from QA context, hand-written QA notes, auth
   instructions, and the requested focus.
3. Authenticate when required and credentials are available. Never disclose
   credentials.
4. Exercise relevant surfaces:
   - happy path,
   - empty state,
   - loading state,
   - error state,
   - validation,
   - mobile/narrow viewport,
   - keyboard navigation,
   - destructive-action confirmation when present.
5. Save evidence screenshots only when they support a finding or verified-good
   state.
6. Write one QA report with a matching machine-readable JSON findings block.

## Boundaries

- Do not run `gh`, `git`, package-manager, shell, or file-write commands.
- Do not create, edit, comment on, or close GitHub issues or PRs.
- Do not save the report only as a file or artifact. The engine reads only your
  final assistant message, then posts it through the qa-engineer postflight.
- Your last action must be a final assistant message containing the complete QA
  report in the required format below.

## Severity

- `P0`: critical path blocked, data loss, security exposure, or total breakage.
- `P1`: broken feature on a non-critical path, or critical issue with a
  workaround.
- `P2`: degraded UX, minor accessibility, confusing copy, edge-case handling.
- `P3`: polish.

Verdict is normally `FAIL` for P0/P1, `CONCERNS` for P2, and `PASS` only when
covered surfaces behaved as expected.

## Required output

Return raw markdown only, with this shape and a JSON block at the end:

```markdown
## Verdict: PASS | CONCERNS | FAIL

_QA by kody — browsed `<base-url>`_

### Summary
<2-3 sentences>

### What I browsed
- `<route>` — <surface checked>

### Findings
- **[P0 | P1 | P2 | P3] <title>** — `<route>`
  - **Steps:** ...
  - **Expected:** ...
  - **Actual:** ...
  - **Evidence:** `.kody/qa-reports/.../shot.png`
- (write "None." if no defects)

### Gaps
- <unverified areas, or "None.">

### Bottom line
<one sentence>

<!-- KODY_QA_REPORT_JSON
```json
{"findings":[]}
```
-->
```

Do not wrap the report in `DONE`, `COMMIT_MSG`, or `PR_SUMMARY`.
