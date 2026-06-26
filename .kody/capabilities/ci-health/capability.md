# CI Health

## Purpose

Own CI readiness as a release or delivery gate.

This agentResponsibility is responsible for answering: is the target PR's CI green enough for
the goal to continue?

## Contract

- The goal provides a PR number and optional goal/evidence keys.
- The agentResponsibility runs the `ci-check` agentAction.
- The agentAction checks GitHub CI for that PR.
- The agentAction emits `KODY_AGENT_RESPONSIBILITY_RESULT` with `pass`, `fail`, or `blocked`.
- If CI is green, the agentResponsibility reports the requested evidence as `true`.
- If CI is pending or failed, the agentResponsibility reports the requested evidence as
  `false` with CI status facts, so the goal can retry later.

## Boundary

The agentResponsibility owns the responsibility. The agentAction owns the mechanics. The goal
only waits for the reported fact.

## Goal Route Example

```json
{
  "evidence": "mainDeployPrGreen",
  "stage": "wait-ci",
  "agentResponsibility": "ci-health",
  "args": {
    "pr": { "fact": "deployPr" },
    "goal": "release-aguy",
    "evidence": "mainDeployPrGreen"
  }
}
```

Do not put `agentAction` in the goal route for this step. The agentResponsibility profile owns
that link and resolves to `ci-check`.
