---
name: system-audit
description: Audit Kody capability, agent, report, and runtime-state wiring.
---

# System Audit Skill

Use this skill when the `system-audit` capability implementation runs.

Runtime state is owned by the engine. Do not ask the capability author to configure raw state keys.

## Method

Audit the coordination surface under `.kody/`. This is a structural check, not a
fixer. Post one consolidated comment on the Kody system audit tracking issue
only when findings exist.

## Scope

Check:

- capabilities in `.kody/capabilities/<slug>/` (`profile.json` plus `capability.md`)
- agent in `.kody/agents/*.md`
- internal capability implementation profiles in `.kody/capabilities/*/`
- reports in `reports/*.md`
- context in `.kody/context/*.md`
- runtime state/history when the engine exposes it

## Checks

1. **Broken agent reference:** A capability profile names `"agent": "<slug>"` but `.kody/agents/<slug>.md` does not exist.
2. **Missing implementation reference:** A capability profile names an implementation/implementation but `.kody/capabilities/<slug>/profile.json` does not exist.
3. **Old capability shape:** A capability profile or body contains raw state schemas, `stage`, `kody-job-next-state`, long shell recipes, or agent/agent identity prompts.
4. **Broken implementation shape:** An internal capability implementation has invalid `profile.json`, a large explanatory `prompt.md`, missing declared skills, or shell steps pointing to missing files.
5. **Stale report:** A report-writing capability has no report, an empty report, or a report older than expected for its cadence.
6. **Stuck runtime:** Runtime evidence shows a non-terminal state stuck well beyond the capability cadence.
7. **Orphan agent:** An agent file owns no active capability. Report as informational, not broken.

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
- `capability-slug` names missing agent `x`. Fix: create `.kody/agents/x.md` or change the capability.
```

## Allowed Commands

- `gh repo view`
- `gh api` reads for `.kody/capabilities`, `.kody/agents`, `reports/` in the configured Kody state repo, `.kody/context`, and history/state when available
- `gh issue list`, `gh issue create`, and `gh issue comment` only for the Kody system audit tracking issue

## Restrictions

- Read-only except for the system-audit tracking issue.
- Do not edit capabilities, agents, reports, context, labels, PRs, or state.
- Do not re-kick work.
- One tracking issue comment at most per tick.
- Stay quiet when there are no findings.
