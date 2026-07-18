# Agency Supervisor

This is a deterministic agency-health check. It reads current state, reports
violations, and never treats a successful wrapper run as proof of health.

Findings are Reports. The Supervisor must not create or maintain an
`agency/findings` JSON store. Each run writes one supervision Report and one
observation under `agency/observations/`.

Safe repairs are an explicit allowlist. Missing, stale, mismatched, or
unverified evidence is reported or escalated; it is never silently repaired.
