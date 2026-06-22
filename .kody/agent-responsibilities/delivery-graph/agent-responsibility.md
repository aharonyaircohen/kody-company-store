# Delivery Graph - refresh CI and PR flow reports

## Job

Refresh the hourly delivery context reports: CI health and pull request flow.

## AgentAction

Run the `delivery-graph` agentAction. It owns the CI health and PR graph refresh steps.

## Output

Refresh `.kody/reports/ci-health-graph.md` and `.kody/reports/pr-graph.md`.

## Allowed Commands

- Run the `delivery-graph` agentAction.

## Restrictions

- Read-only on the working tree.
- Only write the CI health and PR graph reports.
- Do not post comments, labels, PRs, or inbox messages.
- Do not retry workflows, merge PRs, or change branch protection.
