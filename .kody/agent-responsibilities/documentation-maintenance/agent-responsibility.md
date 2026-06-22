# Documentation Maintenance - keep the repo well documented

## Job

Run a weekly documentation-maintenance sweep that reverse-engineers the current repo from code, tests, routes, config, and existing docs, then identifies the most valuable documentation work.

## AgentAction

Run `documentation-maintenance` agentAction.

## Output

A concise docs health report, one tracking issue or issue comment, and one inbox recommendation for the highest-value documentation gap.

## Allowed Commands

- Run `documentation-maintenance` agentAction.

## Restrictions

- Do not hard-code product-specific pages, features, or workflows in the agentResponsibility.
- Community standards are the only fixed checklist.
- Discover product behavior from repo evidence before documenting it.
- Advisory only: do not edit docs, commit, push, merge, or approve from this agentResponsibility.
- Prefer one focused recommendation per run over a broad rewrite.
