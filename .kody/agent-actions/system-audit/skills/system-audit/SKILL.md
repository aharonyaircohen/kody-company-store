---
name: system-audit
description: Audit Kody agentResponsibility, agent, agentAction, report, and runtime-state wiring.
---

# System Audit Skill

Use this skill when the `system-audit` agentAction runs from the matching agentResponsibility.

Runtime state is owned by the engine. Do not ask the agentResponsibility author to configure raw state keys.

## Method

Audit the coordination surface under `.kody/`. This is a structural check, not a
fixer. Post one consolidated comment on the Kody system audit tracking issue
only when findings exist.

## Scope

Check:

- agentResponsibilities in `.kody/agent-responsibilities/<slug>/` (`profile.json` plus `agent-responsibility.md`)
- agent in `.kody/agents/*.md`
- agentActions in `.kody/agent-actions/*/`
- reports in `.kody/reports/*.md`
- context in `.kody/context/*.md`
- runtime state/history when the engine exposes it

## Checks

1. **Broken agent reference:** A agentResponsibility profile names `"agent": "<slug>"` but `.kody/agents/<slug>.md` does not exist.
2. **Missing agentAction reference:** A agentResponsibility profile names an agentAction but `.kody/agent-actions/<slug>/profile.json` does not exist.
3. **Old agentResponsibility shape:** A agentResponsibility profile or body contains raw state schemas, `stage`, `kody-job-next-state`, long shell recipes, or agent/agent identity prompts.
4. **Broken agentAction shape:** An agentAction has invalid `profile.json`, a large explanatory `prompt.md`, missing declared skills, or shell steps pointing to missing files.
5. **Stale report:** A report-writing agentResponsibility has no report, an empty report, or a report older than expected for its cadence.
6. **Stuck runtime:** Runtime evidence shows a non-terminal state stuck well beyond the agentResponsibility cadence.
7. **Orphan agent:** An agent file owns no active agentResponsibility. Report as informational, not broken.

## Tick Procedure

1. Resolve the repo with `gh repo view --json nameWithOwner -q .nameWithOwner`.
2. Read the directories listed in Scope.
3. Run the checks above.
4. If there are no findings, stay quiet.
5. If there are findings, find or open the tracking issue titled `Kody system audit`.
6. Post one grouped comment:

```md
## System Audit - <n> finding(s)

### Broken agent reference
- `agentResponsibility-slug` names missing agent `x`. Fix: create `.kody/agents/x.md` or change the agentResponsibility.
```

## Allowed Commands

- `gh repo view`
- `gh api` reads for `.kody/agent-responsibilities`, `.kody/agents`, `.kody/agent-actions`, `.kody/reports`, `.kody/context`, and history/state when available
- `gh issue list`, `gh issue create`, and `gh issue comment` only for the Kody system audit tracking issue

## Restrictions

- Read-only except for the system-audit tracking issue.
- Do not edit agentResponsibilities, agent, agentActions, reports, context, labels, PRs, or state.
- Do not re-kick work.
- One tracking issue comment at most per tick.
- Stay quiet when there are no findings.
