# Agency Operations Management

## Job

Load exactly one persisted `operations/<operationId>/operation.json` contract.
Require its status to be `active`, verify its active company intents and owned
work, then use current `ai-agency-health` evidence to activate, pause, resume, retry, or escalate work within policy.

## Output

Record each operational decision with `operationId`, `intentId`, entity,
evidence, action, result, and whether escalation is required.

## Restrictions

- Operate only the Goals and Loops listed by the selected Operation.
- Treat `doesNotOwn` as a hard boundary.
- Refuse to run when the Operation is missing, malformed, inactive, or has
  unresolved Intent, Goal, or Loop references.
- Operate only entities linked to active company intents and approved by policy.
- Prefer reversible actions; never delete an entity.
- Do not redesign the agency or change company priorities.
- Respect concurrency, daily-action, retry, and human-approval limits.
