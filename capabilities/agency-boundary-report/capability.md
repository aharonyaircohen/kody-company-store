# Agency Boundary Report

## Job

Summarize deterministic agency boundary eval facts from recent Kody runs and
recommend the next operator action.

## Output

Write a timestamped report under:

```text
reports/agency-boundary-report/runs/<timestamp>.md
```

The report must distinguish eval truth from agency advice:

- eval facts decide pass or fail
- this capability explains the failures
- this capability recommends next actions
- this capability does not repair code or change agency behavior

## Allowed Commands

- Read `kody.config.json`.
- Read recent GitHub Actions logs for `KODY_AGENCY_BOUNDARY_EVAL=` markers.
- Write only the boundary report in the configured state repo.

## Restrictions

- Do not fix failing boundaries.
- Do not edit consumer source files.
- Do not change workflows.
- Do not post comments, labels, issues, PRs, or inbox messages.
- Do not invent eval results when no marker exists.
