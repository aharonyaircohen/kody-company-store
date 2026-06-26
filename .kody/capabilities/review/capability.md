# PR Review

## Job

Review a pull request and report actionable findings.

## AgentAction

Run the `review` agentAction. Its review skills own the detailed review method.

## Output

A review comment or report on the target pull request.

## Allowed Commands

- Run the `review` agentAction.

## Restrictions

- Do not edit code from this agentResponsibility.
- Prioritize correctness, regressions, missing tests, and security risks.
- Keep findings tied to concrete files or behavior.
