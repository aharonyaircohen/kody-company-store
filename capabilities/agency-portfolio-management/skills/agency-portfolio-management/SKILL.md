---
name: agency-portfolio-management
description: Build and scale bounded Operations from active company Intents.
---

# Agency Portfolio Management

## Model

- Intent owns why.
- Operation owns one durable responsibility and its accountable Goals and Loops.
- Goal owns a desired outcome.
- Loop owns recurring attention and cadence.
- Capability owns one reusable ability.
- Workflow owns an ordered multi-step run.
- Agent owns identity and judgment.
- State owns what happened.

## Method

1. Read active company Intents and answer from them: desired outcome, why it matters, priority, principles, success measures, and hard rules no Operation may violate. If any required answer is missing, record the gap instead of inventing it.
2. Inventory current Operations, Goals, Loops, Capabilities, Workflows, and Agents plus agency-health evidence.
3. For each priority, first reuse an existing Operation whose responsibility and `doesNotOwn` boundary fit. Do not create an Operation merely to group work.
4. If a stable delegated responsibility is genuinely missing, draft the minimum `operations/<id>/operation.json` contract with version, id, name, responsibility, `doesNotOwn`, `intentIds`, Goals, Loops, status, and timestamps.
5. Start the new Operation as `proposed`. Move it to `provisioning` only after approval. During provisioning, reuse existing Goals and Loops first; create traceable implementation tasks only for missing work that the contract requires.
6. Move an Operation to `active` only after every linked Intent is active, at least one Goal or Loop is owned, every reference exists as the correct model, and Intent policy still permits operation. Otherwise leave it proposed or provisioning with exact issues.
7. For each missing or unhealthy entity inside an Operation, reuse, repair, merge, pause, or retire before proposing a new entity. Capabilities, Workflows, and Agents remain shared; do not copy them into the Operation.
8. Record a decision with `operationId`, entity type, current evidence, proposed change, approval requirement, and owner.
9. For an approved structural change, create one traceable implementation task through `gh`; do not invent an unsupported command or directly rewrite production assets.
10. Do not repeat an open task or unchanged proposal.

## State output

- The portfolio decision file is `<state.path>/agency-portfolio.json` in the state repo configured by `kody.config.json`.
- Approved Operation contracts live at `<state.path>/operations/<id>/operation.json`. Use `gh api --method PUT` with the current blob `sha` when updating. After each write, read it back and verify its responsibility, `doesNotOwn`, `intentIds`, Goals, Loops, lifecycle status, and timestamps. If the write or verification fails, finish with `FAILED: <reason>`.
- A roll-forward is not a new decision. Compare the decision-bearing fields with the current file before writing; changes only to timestamps, job IDs, wording, evidence ordering, or appended no-change history do not count. When entity status, evidence meaning, proposed change, approval requirement, and owner are unchanged, do not PUT and report `no change` from the existing file.
- Do not clone the state repo and do not use Write or Edit outside the target workspace. Build the JSON payload from Bash and persist it through the GitHub contents API with `gh api --method PUT`; include the current blob `sha` when replacing an existing file.
- After the PUT, read it back through `gh api` and verify each entity's active `intentId`, type, evidence, proposed change, approval requirement, and owner. If persistence or verification fails, finish with `FAILED: <reason>`; never report a successful management decision that exists only in the agent session.
- Do not run the target repo's full test or typecheck suites during a portfolio review. Use existing results and narrow evidence checks so one management tick fits inside its configured cadence.

The Agent running this Capability makes the portfolio decision. This does not create a separate Manager model; runtime operation remains a separate Capability.
