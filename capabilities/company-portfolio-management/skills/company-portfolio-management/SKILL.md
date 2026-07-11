---
name: company-portfolio-management
description: Set company growth priorities from active company intents and current evidence.
---

# Company Portfolio Management

## Method

1. Read active company intents and their policy limits from the configured Kody state.
2. Read company results, current portfolio links, and `reports/ceo-performance-review.md` when available.
3. Remove proposals that lack an active `intentId`, duplicate current work, or lack evidence.
4. Rank the remaining priorities by expected company value, urgency, confidence, and cost.
5. Record only the smallest useful portfolio decision in the configured state repo, using `gh`, with one row per priority: `intentId`, outcome, evidence, rank, and next owner.
6. When evidence has not changed, leave the prior decision stable and report no change.

## State output

- The decision file is `<state.path>/portfolio.json` in the state repo configured by `kody.config.json`.
- Do not clone the state repo and do not use Write or Edit outside the target workspace. Build the JSON payload from Bash and persist it through the GitHub contents API with `gh api --method PUT`; include the current blob `sha` when replacing an existing file.
- After the PUT, read it back through `gh api` and verify the active `intentId`, rank, outcome, evidence, and next owner. If persistence or verification fails, finish with `FAILED: <reason>`; never report a successful management decision that exists only in the agent session.
- Do not run the target repo's full test or typecheck suites during a portfolio review. Use existing results and narrow evidence checks so one management tick fits inside its configured cadence.

CEO owns company priorities. CTO decides agency design. COO operates approved agency entities.
Never bypass intent policy fields such as human approval or action limits.
