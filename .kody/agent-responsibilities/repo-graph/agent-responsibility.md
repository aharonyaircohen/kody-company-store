# Repo Graph - refresh dependency and documentation topology reports

## Job

Refresh the daily repository topology reports: dependency graph and documentation graph.

## AgentAction

Run the `repo-graph` agentAction. It owns the dependency and docs graph refresh steps.

## Output

Refresh `.kody/reports/dependency-graph.md` and `.kody/reports/docs-graph.md`.

## Allowed Commands

- Run the `repo-graph` agentAction.

## Restrictions

- Read-only on the working tree.
- Only write the dependency and docs graph reports.
- Do not install packages, fetch external docs links, post comments, labels, PRs, or inbox messages.
- Do not move, rename, or delete files.
