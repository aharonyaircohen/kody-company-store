# PR Conflict Resolution

## Job

Resolve merge conflicts on an existing pull request branch.

## AgentAction

Run the `resolve` agentAction. The engine owns the implementation details.

## Output

An updated pull request branch with conflicts resolved.

## Allowed Commands

- Run the `resolve` agentAction.

## Restrictions

- Preserve both sides of the intended behavior when resolving conflicts.
- Do not add unrelated changes.
- Do not merge the pull request from this agentResponsibility.
