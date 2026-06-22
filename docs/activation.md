# Activation

The store is a catalog, not an auto-run list. Consumer repos decide which shared company model is active from `kody.config.json`.

```json
{
  "company": {
    "activeGoals": ["prs-stay-mergeable", "product-quality"]
  }
}
```

## AgentGoals and AgentLoops

Store goals are inactive agentGoal or agentLoop templates. Consumer repos activate the company model through `company.activeGoals`.

AgentLoops own scheduled agentResponsibility decisions. A agentResponsibility may declare `every`, `agent`, and `agentAction`, but the agentLoop tick decides whether that agentResponsibility is due, skipped, blocked, or selected.

Default agentLoop templates:

- `prs-stay-mergeable`
- `product-quality`
- `codebase-health`
- `release-safety`
- `kody-company-health`

Consumer repos may also define local goal templates.

```text
.kody/goals/templates/<slug>/state.json
<statePath>/goals/instances/<id>/state.json
```

String activation creates one stable runtime instance from a matching store/local template, or activates an existing instance by id.

```json
{ "company": { "activeGoals": ["prs-stay-mergeable"] } }
```

Scheduled activation creates a fresh runtime instance from a template each time bucket, persists it to the configured state repo, then ticks that instance.

```json
{ "company": { "activeGoals": [{ "template": "release-safety", "every": "1w" }] } }
```

Supported intervals are `Nm`, `Nh`, `Nd`, and `Nw`, for example `15m`, `2h`, `1d`, and `1w`.

Store goals must not contain repo-specific runtime history. Runtime goal progress belongs in the configured state repo.

## AgentResponsibilities

Store agentResponsibilities are available responsibilities or commands. They are no longer the main scheduled fan-out surface.

Rules:

- Scheduled company behavior should be activated through `company.activeGoals`.
- AgentResponsibility cadence is reusable agentResponsibility information; goal tick owns the scheduling decision.
- Manual agentResponsibility runs still work from the dashboard or workflow dispatch.
- `company.activeAgentResponsibilities` is legacy compatibility; do not use it for new scheduled company behavior.
- Local repo agentResponsibilities remain repo-owned.
- Do not add `disabled: true` to all store agentResponsibilities.
- Activation belongs in the consumer repo, not the catalog item.

## Mental Model

```text
kody-store = menu
consumer repo = decides what is enabled
agentResponsibility = available responsibility or command
agentGoal/agentLoop = operator promise that owns scheduled agentResponsibility decisions
activation = permission to run
scheduled agentLoop = template creates new runtime instance per bucket
```
