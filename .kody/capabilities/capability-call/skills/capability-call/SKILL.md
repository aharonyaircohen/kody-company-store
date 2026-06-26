---
name: capability-call
description: Propose one high-ROI missing capability the system does not already have.
---

# Capability Call Skill

Use this skill when the `capability-call` executable runs from the matching capability.

Runtime state is owned by the engine. Do not ask the capability author to configure raw state keys.

## Method

Propose one useful missing capability. The proposal is advisory only: create a GitHub
issue with the reason, score, suggested capability profile fields, and any executable or
skill that would be needed. Do not write the capability folder yourself.

## Candidate Rules

- Read `.kody/capabilities/` first; never propose a capability that already exists.
- Read `.kody/memory/` for prior rejected or dismissed proposals.
- Never re-propose a rejected slug.
- Respect dismissed slugs until their cooling-off window expires.
- Prefer gaps that can be expressed as a simple capability plus executable.

## Proposal Shape

The issue should include:

- proposed capability slug
- agent owner
- goal/loop schedule that would run it
- stage template
- executable slug
- expected report/comment/output
- safety limits
- why this capability is worth adding now

## Tick Procedure

1. Gather existing capabilities, agent, executables, reports, and memories.
2. Build a small candidate list of missing recurring capabilities.
3. Score each candidate by impact, confidence, noise risk, and implementation cost.
4. Pick the best candidate that has not been rejected or recently dismissed.
5. If no candidate is strong enough, do nothing.
6. Otherwise create one proposal issue labeled `kody:ceo-proposal`.
7. Record the proposed slug in runtime state so it is not proposed again while open.

## Allowed Commands

- `gh api` reads for `.kody/capabilities`, `.kody/agents`, `.kody/executables`, `reports/` in the configured Kody state repo, and `.kody/memory`
- `gh issue list`
- `gh issue create`
- `gh label create` when the proposal label is missing

## Restrictions

- One proposal per tick.
- Never create or edit capability folders.
- Never create or edit executables.
- Never re-surface rejected proposals.
- Better to stay quiet than propose low-signal work.
