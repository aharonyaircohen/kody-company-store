# CI Health

## Purpose

Own CI readiness as a release or delivery gate.

This capability is responsible for answering: is the target PR's CI green enough for
the goal to continue?

## Contract

- The goal provides a PR number and optional goal/evidence keys.
- The capability runs the `ci-check` executable.
- The executable checks GitHub CI for that PR.
- The executable emits `KODY_CAPABILITY_RESULT` with `pass`, `fail`, or `blocked`.
- If CI is green, the capability reports the requested evidence as `true`.
- If CI is pending or failed, the capability reports the requested evidence as
  `false` with CI status facts, so the goal can retry later.

## Boundary

The capability owns the intent. The executable owns the mechanics. The goal
only waits for the reported fact.

## Goal Route Example

```json
{
  "evidence": "mainDeployPrGreen",
  "stage": "wait-ci",
  "capability": "ci-health",
  "args": {
    "pr": { "fact": "deployPr" },
    "goal": "release-aguy",
    "evidence": "mainDeployPrGreen"
  }
}
```

Do not put `executable` in the goal route for this step. The capability profile owns
that link and resolves to `ci-check`.
