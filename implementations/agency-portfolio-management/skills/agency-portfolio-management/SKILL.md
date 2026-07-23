---
name: agency-portfolio-management
description: Build and scale bounded Operations from active company Intents.
---

# Agency Director — Agency Portfolio Management

The COO acts here as the Agency Director: it reviews the agency portfolio,
chooses the next structural decision, and delegates execution to the
responsible Operation. It does not replace the Council roles or operate their
work directly.

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
4. If a stable delegated responsibility is genuinely missing, create one focused, traceable request for `operation-creator`. Include the proposed id, responsibility, `doesNotOwn`, active `intentIds`, accountable Goals and Loops, current evidence, and approval requirement. Do not draft or write `operations/<id>/operation.json` yourself.
5. Treat the creator's review PR as the Operation proposal. A human must approve it before the Operation moves from `proposed` to `provisioning`. During provisioning, reuse existing Goals and Loops first; create traceable implementation tasks only for missing work that the approved contract requires.
6. Move an Operation to `active` only after every linked Intent is active, at least one Goal or Loop is owned, every reference exists as the correct model, and Intent policy still permits operation. Otherwise leave it proposed or provisioning with exact issues.
7. For each missing or unhealthy entity inside an Operation, reuse, repair, merge, pause, or retire before proposing a new entity. Capabilities, Workflows, and Agents remain shared; do not copy them into the Operation.
8. Record a decision with `operationId`, entity type, current evidence, proposed change, approval requirement, and owner.
9. For an approved structural change, create one traceable implementation task through `gh`. For a missing Operation, the task must explicitly request the `operation-creator` capability; do not invent an unsupported command or directly rewrite production assets.
10. Do not repeat an open task or unchanged proposal.

## State output

- The portfolio decision file is `<state.path>/agency-portfolio.json` in the state repo configured by `kody.config.json`.
- Operation contracts live at `<state.path>/operations/<id>/operation.json`, but this capability never authors them. `operation-creator` validates the contract and opens the review PR; portfolio management only records the decision and follows the reviewed lifecycle.
- A roll-forward is not a new decision. Compare the decision-bearing fields with the current file before writing; changes only to timestamps, job IDs, wording, evidence ordering, or appended no-change history do not count. When entity status, evidence meaning, proposed change, approval requirement, and owner are unchanged, do not PUT and report `no change` from the existing file.
- Do not clone the state repo and do not use Write or Edit outside the target workspace. Build the JSON payload from Bash and persist it through the GitHub contents API with `gh api --method PUT`; include the current blob `sha` when replacing an existing file.
- After the PUT, read it back through `gh api` and verify each entity's active `intentId`, type, evidence, proposed change, approval requirement, and owner. If persistence or verification fails, finish with `FAILED: <reason>`; never report a successful management decision that exists only in the agent session.
- Do not run the target repo's full test or typecheck suites during a portfolio review. Use existing results and narrow evidence checks so one management tick fits inside its configured cadence.

The Agency Director makes the portfolio decision. This does not create a
separate Manager model; runtime operation remains a separate Capability.
