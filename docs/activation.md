# Activation

The store is a catalog, not an auto-run list. Consumer repos decide which shared company model is active from `kody.config.json`.

```json
{
  "company": {
    "activeCapabilities": ["fix-ci", "review"],
    "activeGoals": ["prs-stay-mergeable", "ci-health", "product-quality", "ai-agency-health"]
  }
}
```

## Capabilities

Store capabilities are inactive shared abilities. Consumer repos activate them
through `company.activeCapabilities`.

```json
{ "company": { "activeCapabilities": ["fix-ci", "review"] } }
```

Capability activation is permission to resolve and run the shared capability for
that consumer repo. Local `.kody/capabilities/<slug>/` folders remain repo-owned
and override store capabilities with the same slug.

## AgentGoals and AgentLoops

Store goals are inactive agentGoal or agentLoop templates. Consumer repos activate the company model through `company.activeGoals`.

AgentLoops own when capabilities run. A capability declares its owner and runtime
contract; the agentLoop tick decides which capability runs.

Default agentLoop templates:

- `prs-stay-mergeable`
- `ci-health`
- `product-quality`
- `codebase-health`
- `release-safety`
- `daily-web-release-loop`
- `kody-company-health`
- `ai-agency-health`

`ai-agency-health` should answer whether the current repo's AI agency is
healthy. Its observe capability writes a repo-local health matrix report; it
does not fix, install, promote, comment, or open PRs. See
[ai-agency-health-matrix.md](ai-agency-health-matrix.md).

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

## Mental Model

```text
kody-store = menu
consumer repo = decides what is enabled
capability = available shared ability
agentGoal/agentLoop = operator promise that owns when capabilities run
activation = permission to run
scheduled agentLoop = template creates new runtime instance per bucket
```
