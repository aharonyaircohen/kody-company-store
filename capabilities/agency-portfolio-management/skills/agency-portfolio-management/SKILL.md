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

CTO owns agency design. CEO owns priority. COO owns runtime operation.
