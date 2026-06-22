---
name: agent-responsibility-review
description: Review one agentResponsibility at a time for design soundness, reachable wiring, cadence, and observed output.
---

# AgentResponsibility Review Skill

Use this skill when the `agent-responsibility-review` agentAction runs from the matching agentResponsibility.

Runtime state is owned by the engine. Do not ask the agentResponsibility author to configure raw state keys.

## Method

Review one agentResponsibility from `.kody/agent-responsibilities/` per tick. This is a design and evidence
review, not a live execution. The goal is to catch agentResponsibilities that no longer fit the
current structure.

## Current AgentResponsibility Shape

A healthy agentResponsibility is short and has:

- `profile.json` with `agent` and `agentAction` or `agentActions`
- `agent-responsibility.md` with a concise human-readable contract
- a clear `Job`
- a small `AgentAction` section
- output and safety limits
- no raw state schema
- no shell recipe or long prompt

The agentAction should hold the method:

- `.kody/agent-actions/<slug>/profile.json`
- `.kody/agent-actions/<slug>/prompt.md`
- `.kody/agent-actions/<slug>/skills/<skill>/SKILL.md`
- optional agentAction-owned `*.sh` scripts only when real scripts exist

## Tick Procedure

1. Resolve the repo with `gh repo view --json nameWithOwner -q .nameWithOwner`.
2. List `.kody/agent-responsibilities/<slug>/` folders, sorted by slug, excluding `agent-responsibility-review`.
3. Pick the next slug from runtime state. If the cycle is complete, post a short cycle summary and reset the reviewed list.
4. Read the selected agentResponsibility, its named agentAction folder, and recent runtime evidence:
   - agentResponsibility `profile.json` and `agent-responsibility.md`
   - agentAction `profile.json`
   - agentAction `prompt.md`
   - agentAction skills and scripts
   - report file, when the agentResponsibility declares or clearly writes one
   - state/history if the engine exposes it
5. Post a finding only when the agentResponsibility is `BROKEN` or `WARN`.

## Review Checklist

- **Goal clarity:** The agentResponsibility has one concrete, checkable job.
- **Profile metadata:** `agent` and `agentAction` or `agentActions` are present and point to real repo objects.
- **AgentAction wiring:** The agentAction exists, has valid JSON, has a tiny prompt, and loads at least one skill unless it is deterministic.
- **State model:** The agentResponsibility does not define raw state keys or require the author to paste a state block. Runtime state belongs to the engine.
- **No command recipe in agentResponsibility:** Bash, `gh`, Python, and long step-by-step logic belong in agentAction skills or agentAction-owned scripts.
- **Output path:** Reports go under `reports/`; durable human guidance goes under `.kody/context/`; hidden cursors stay in runtime state.
- **Observed behavior:** For enabled agentResponsibilities, recent state/report/activity should roughly match the declared cadence. Disabled agentResponsibilities are reviewed for design only.
- **One-action limit:** The method should not spam many comments, issues, or commits in one tick unless the agentAction explicitly batches a report write.

## Allowed Commands

- `gh repo view`
- `gh api` reads for `.kody/agent-responsibilities`, `.kody/agent-actions`, `reports/` in the configured Kody state repo, and state/history when available
- `gh issue list`, `gh issue create`, and `gh issue comment` only for the Kody agentResponsibility review tracking issue

## Restrictions

- Read-only on reviewed agentResponsibilities and agentActions.
- Do not fix the agentResponsibility being reviewed.
- Do not re-kick or relabel work.
- One reviewed agentResponsibility per tick.
- One tracking issue comment at most per tick.
