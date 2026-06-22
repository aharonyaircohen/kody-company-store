# Assets

Kody store assets live under roots declared in `kody-store.json`.

```json
{
  "assetRoots": {
    "agent-responsibilities": ".kody/agent-responsibilities",
    "agent-actions": ".kody/agent-actions",
    "goals": ".kody/goals/templates",
    "agent": ".kody/agents"
  }
}
```

The slug is the lookup key.

Availability is separate from activation. See [activation.md](activation.md).

## AgentResponsibilities

Path:

```text
.kody/agent-responsibilities/<slug>/
```

Common files:

- `profile.json`: agentResponsibility metadata, cadence, agent, mentions, and agentAction link.
- `agent-responsibility.md`: human-readable agentResponsibility instructions.

Store agentResponsibilities are inactive by default. `every` is a suggested cadence, not
permission to run in every repo. A consumer activates store agentResponsibilities in
`kody.config.json`:

```json
{ "company": { "activeAgentResponsibilities": ["release"] } }
```

## AgentActions

Path:

```text
.kody/agent-actions/<slug>/
```

Common files:

- `profile.json`: agentAction metadata and runtime contract.
- `prompt.md`: prompt used by the agentAction.
- `*.sh`: optional helper scripts.

AgentAction scripts should consume environment variables provided by the runtime.
They should not own consumer secrets or decrypt repo-local vaults inside store.

## Agent

Path:

```text
.kody/agents/<slug>.md
```

Agent files are agent identities. Concrete job behavior should live in agentResponsibilities and
agentActions, not in agent identity files.

## Goals

Path:

```text
.kody/goals/templates/<slug>/state.json
```

Goals are managed agentGoal and agentLoop templates. A shared template should be
portable enough for a consumer repo to activate as a starting state, then fill
runtime facts.

Store goal templates should use `state: "inactive"`. Consumer runtime instances
become `active`.

Store goals are inactive by default. A consumer activates store goals in
`kody.config.json`:

```json
{ "company": { "activeGoals": ["web-release"] } }
```

Scheduled activation creates a fresh runtime instance from the template:

```json
{
  "company": {
    "activeGoals": [
      { "template": "web-release", "every": "1w", "facts": { "issue": 123 } }
    ]
  }
}
```

Shared store goals must not contain consumer secrets, run logs, or completed
runtime history.
