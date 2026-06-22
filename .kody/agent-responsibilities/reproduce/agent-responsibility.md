# Bug Reproduction

## Job

Reproduce a bug and capture the failure signature without fixing it.

## AgentAction

Run the `reproduce` agentAction. Its bug reproduction skill owns the detailed method.

## Output

A failing test or reproduction notes that prove the bug.

## Allowed Commands

- Run the `reproduce` agentAction.

## Restrictions

- Do not fix the bug from this agentResponsibility.
- Preserve the failure signal for a later fix agentResponsibility.
- Report clearly if the bug cannot be reproduced.
