# AgentResponsibility Review

## Job

Review one agentResponsibility at a time for design soundness, reachable steps, cadence, and observed output.

## AgentAction

Run the `agent-responsibility-review` agentAction. Its skill owns the detailed method and runtime state handling.

## Output

A finding comment or cycle summary on the agent-responsibility-review tracking issue.

## Allowed Commands

- Run the `agent-responsibility-review` agentAction.

## Restrictions

- Do not execute or fix the reviewed agentResponsibility.
- Do not review yourself.
- One agentResponsibility and one comment at most per tick.
- Read-only except for the tracking issue.
