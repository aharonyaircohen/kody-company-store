---
name: agency-operations-management
description: Operate one active persisted Operation within its exact Goal and Loop scope.
---

# Agency Operations Management

## Method

1. Read the operator request and extract exactly one safe lowercase `operationId`. Refuse ambiguous, missing, or invalid ids.
2. Resolve the configured state repository, path, and branch from `kody.config.json`; use the documented defaults when fields are absent. Do not clone the state repo.
3. With `gh api`, read `operations/<operationId>/operation.json` from that state path. Treat this file as the authoritative runtime scope.
4. Validate version `1`, matching `id`, `status: active`, non-empty `intentIds`, non-empty `doesNotOwn`, and at least one owned Goal or Loop. Refuse malformed or inactive Operations.
5. Read every linked Intent and require it to be active. Read every listed Goal and Loop and verify that it exists as the expected model. Refuse unresolved references; never silently drop one.
6. Read policy limits, current run state, and the latest `ai-agency-health` evidence only for those owned Goals and Loops. Treat `doesNotOwn` and linked Intent hard rules as mandatory boundaries.
7. For each unhealthy or idle owned entity, choose the smallest safe action: activate, pause, resume, retry, or escalate. Never act on an entity that is not listed in the Operation, even if it appears related.
8. Use `gh` only. Take an action only when it is supported, reversible, within policy, and not already pending. Never delete an entity or redesign the agency.
9. Verify the resulting state and record `operationId`, `intentId`, entity, evidence, action, and result.
10. Escalate repeated failures, structural defects, or approval-gated actions to the operator. When all scoped evidence is healthy, make no change and avoid report churn.
