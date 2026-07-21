# PR Review

## Job

Review a pull request and report actionable findings.

## Implementation

Run the `review` implementation. Its review skills own the detailed review method.

## Output

A review comment on the target pull request. The final response must be the
comment body and must include this exact machine-readable heading:

```md
## Verdict: PASS
```

Use exactly one of:

- `## Verdict: PASS` when there are no blocking or advisory findings.
- `## Verdict: CONCERNS` when there is at least one verified `WARN` finding.
- `## Verdict: FAIL` when the PR should not merge until fixes are made.

The heading may be followed by summary and findings sections, but do not replace
it with `LGTM`, bold text, or another verdict spelling.

## Allowed Commands

- Run the `review` implementation.

## Restrictions

- Do not edit code from this capability.
- Prioritize correctness, regressions, missing tests, and security risks.
- Keep findings tied to concrete files or behavior.
