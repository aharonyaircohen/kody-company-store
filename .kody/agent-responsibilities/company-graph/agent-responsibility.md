# Company Graph - derive and refresh the orchestration graph

## Job

Refresh the machine-readable graph of context, agentResponsibilities, agent, agentActions, reports, goals, and issue edges.

## AgentAction

Run the `company-graph` agentAction. Its skill owns the detailed method and runtime state handling.

## Output

Refresh `.kody/reports/company-graph.md`.

## Allowed Commands

- Run the `company-graph` agentAction.

## Restrictions

- Read-only on the working tree.
- Only write the company graph report.
- Do not post comments, labels, PRs, or inbox messages.
- Do not summarize file prose; derive structure.
