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

CEO owns company priorities. CTO decides agency design. COO operates approved agency entities.
Never bypass intent policy fields such as human approval or action limits.
