# AgentResponsibility Call

## Job

Propose one high-ROI missing agentResponsibility that the system does not already have.

## AgentAction

Run the `agent-responsibility-call` agentAction. Its skill owns the detailed method and runtime state handling.

## Output

A proposal issue for operator approval.

## Allowed Commands

- Run the `agent-responsibility-call` agentAction.

## Restrictions

- One proposal per tick.
- Do not create the agentResponsibility directly.
- Never re-propose rejected ideas.
- Respect dismissed ideas until their cooling-off window expires.
