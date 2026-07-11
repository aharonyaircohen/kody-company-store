---
name: agency-operations-management
description: Monitor and operate approved intent-backed agency entities safely.
---

# Agency Operations Management

## Method

1. Read active company intents, approved portfolio links, policy limits, current run state, and the latest `ai-agency-health` evidence.
2. Ignore entities with no active `intentId`; escalate the missing ownership instead of operating them.
3. For each unhealthy or idle approved entity, choose the smallest safe action: activate, pause, resume, retry, or escalate.
4. Use `gh` only. Take an action only when it is supported, reversible, within policy, and not already pending.
5. Verify the resulting state and record `intentId`, entity, evidence, action, and result.
6. Escalate repeated failures, structural defects, or approval-gated actions to CTO or the operator. Do not redesign them.
7. When all evidence is healthy, make no change and avoid report churn.

COO owns runtime operation. CTO owns agency design. CEO owns company priority.
