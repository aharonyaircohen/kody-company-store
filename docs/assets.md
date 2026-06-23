# Assets

Kody store assets live under roots declared in `kody-store.json`.

```json
{
  "assetRoots": {
    "agent-responsibilities": ".kody/agent-responsibilities",
    "agent-actions": ".kody/agent-actions",
    "commands": ".kody/commands",
    "goals": ".kody/goals/templates",
    "agent": ".kody/agents",
    "cms": "cms"
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

- `profile.json`: agentResponsibility metadata, agent, mentions, and agentAction link.
- `agent-responsibility.md`: human-readable agentResponsibility instructions.

Store agentResponsibilities are inactive by default. They do not own cadence.
A consumer activates scheduled company behavior through goal/loop templates in
`kody.config.json`:

```json
{ "company": { "activeGoals": ["release-safety"] } }
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

## Commands

Path:

```text
.kody/commands/<slug>.md
```

Commands are Dashboard slash command templates. Frontmatter stores the menu
description and argument hint; the body is the prompt template expanded by
KodyChat.

Consumer repo commands override store commands by slug. Store commands must not
contain repo-specific runtime state, generated output, or secrets.

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

## CMS

Path:

```text
cms/
```

Common folders:

- `contract/`: generic CMS config validation and operation generation.
- `adapters/`: generic storage adapters such as `mongodb` and `github`.
- `examples/`: state-repo config examples.
- `tests/`: Store-owned adapter contract tests.

CMS adapters are infrastructure capabilities, not consumer behavior. Consumer
repos or their state repos own collection config, environment selection, and
secret names. Store CMS assets must not contain raw database credentials or
consumer-specific runtime data.
