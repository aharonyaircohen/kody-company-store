---
name: agency-portfolio-management
description: Build and scale the agency portfolio from active company intents and CEO priorities.
---

# Agency Portfolio Management

## Model

- Intent owns why.
- Goal owns a desired outcome.
- Loop owns recurring attention and cadence.
- Capability owns one reusable ability.
- Workflow owns an ordered multi-step run.
- Agent owns identity and judgment.
- State owns what happened.

## Method

1. Read active company intents, their policy limits, and the latest CEO portfolio priorities.
2. Inventory current goals, loops, capabilities, workflows, and agents plus agency-health evidence.
3. For each priority, identify the smallest missing or unhealthy entity and attach its `intentId`.
4. Reuse, repair, merge, pause, or retire before proposing a new entity.
5. Record a decision with entity type, current evidence, proposed change, approval requirement, and owner.
6. For an approved change, create one traceable implementation task through `gh`; do not invent an unsupported command or directly rewrite production assets.
7. Do not repeat an open task or unchanged proposal.

## State output

- The portfolio decision file is `<state.path>/agency-portfolio.json` in the state repo configured by `kody.config.json`.
- A roll-forward is not a new decision. Compare the decision-bearing fields with the current file before writing; changes only to timestamps, job IDs, wording, evidence ordering, or appended no-change history do not count. When entity status, evidence meaning, proposed change, approval requirement, and owner are unchanged, do not PUT and report `no change` from the existing file.
- Do not clone the state repo and do not use Write or Edit outside the target workspace. Build the JSON payload from Bash and persist it through the GitHub contents API with `gh api --method PUT`; include the current blob `sha` when replacing an existing file.
- After the PUT, read it back through `gh api` and verify each entity's active `intentId`, type, evidence, proposed change, approval requirement, and owner. If persistence or verification fails, finish with `FAILED: <reason>`; never report a successful management decision that exists only in the agent session.
- Do not run the target repo's full test or typecheck suites during a portfolio review. Use existing results and narrow evidence checks so one management tick fits inside its configured cadence.

CTO owns agency design. CEO owns priority. COO owns runtime operation.
