---
name: agent-responsibility-call
description: Propose one high-ROI missing agentResponsibility the system does not already have.
---

# AgentResponsibility Call Skill

Use this skill when the `agent-responsibility-call` agentAction runs from the matching agentResponsibility.

Runtime state is owned by the engine. Do not ask the agentResponsibility author to configure raw state keys.

## Method

Propose one useful missing agentResponsibility. The proposal is advisory only: create a GitHub
issue with the reason, score, suggested agentResponsibility profile fields, and any agentAction or
skill that would be needed. Do not write the agentResponsibility folder yourself.

## Candidate Rules

- Read `.kody/agent-responsibilities/` first; never propose a agentResponsibility that already exists.
- Read `.kody/memory/` for prior rejected or dismissed proposals.
- Never re-propose a rejected slug.
- Respect dismissed slugs until their cooling-off window expires.
- Prefer gaps that can be expressed as a simple agentResponsibility plus agentAction.

## Proposal Shape

The issue should include:

- proposed agentResponsibility slug
- agent owner
- cadence
- stage template
- agentAction slug
- expected report/comment/output
- safety limits
- why this agentResponsibility is worth adding now

## Tick Procedure

1. Gather existing agentResponsibilities, agent, agentActions, reports, and memories.
2. Build a small candidate list of missing recurring responsibilities.
3. Score each candidate by impact, confidence, noise risk, and implementation cost.
4. Pick the best candidate that has not been rejected or recently dismissed.
5. If no candidate is strong enough, do nothing.
6. Otherwise create one proposal issue labeled `kody:ceo-proposal`.
7. Record the proposed slug in runtime state so it is not proposed again while open.

## Allowed Commands

- `gh api` reads for `.kody/agent-responsibilities`, `.kody/agents`, `.kody/agent-actions`, `.kody/reports`, and `.kody/memory`
- `gh issue list`
- `gh issue create`
- `gh label create` when the proposal label is missing

## Restrictions

- One proposal per tick.
- Never create or edit agentResponsibility folders.
- Never create or edit agentActions.
- Never re-surface rejected proposals.
- Better to stay quiet than propose low-signal work.
