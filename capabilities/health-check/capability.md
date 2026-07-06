# Kody Health Check

## Job

Report Kody-assigned tasks that have not been updated within the expected window.

## Implementation

Run the `health-check` implementation. Its skill owns the detailed method and runtime state handling.

## Output

Refresh `.kody/reports/health-check.md`.

## Allowed Commands

- Run the `health-check` implementation.

## Restrictions

- Read-only on scanned issues.
- Do not re-kick or relabel tasks.
- Never create or comment on issues from this capability.
- Only write the health-check report.
