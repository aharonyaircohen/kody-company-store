---
name: capability-review
description: Review one capability at a time for design soundness, reachable wiring, cadence, and observed output.
---

# Capability Review Skill

Use this skill when the `capability-review` executable runs from the matching capability.

Runtime state is owned by the engine. Do not ask the capability author to configure raw state keys.

## Method

Review one capability from `.kody/capabilities/` per tick. This is a design and evidence
review, not a live execution. The goal is to catch capabilities that no longer fit the
current structure.

## Current Capability Shape

A healthy capability is short and has:

- `profile.json` with `agent` and `executable` or `executables`
- `capability.md` with a concise human-readable contract
- a clear `Job`
- a small `Executable` section
- output and safety limits
- no raw state schema
- no shell recipe or long prompt

The executable should hold the method:

- `.kody/executables/<slug>/profile.json`
- `.kody/executables/<slug>/prompt.md`
- `.kody/executables/<slug>/skills/<skill>/SKILL.md`
- optional executable-owned `*.sh` scripts only when real scripts exist

## Tick Procedure

1. Resolve the repo with `gh repo view --json nameWithOwner -q .nameWithOwner`.
2. List `.kody/capabilities/<slug>/` folders, sorted by slug, excluding `capability-review`.
3. Pick the next slug from runtime state. If the cycle is complete, post a short cycle summary and reset the reviewed list.
4. Read the selected capability, its named executable folder, and recent runtime evidence:
   - capability `profile.json` and `capability.md`
   - executable `profile.json`
   - executable `prompt.md`
   - executable skills and scripts
   - report file, when the capability declares or clearly writes one
   - state/history if the engine exposes it
5. Post a finding only when the capability is `BROKEN` or `WARN`.

## Review Checklist

- **Goal clarity:** The capability has one concrete, checkable job.
- **Profile metadata:** `agent` and `executable` or `executables` are present and point to real repo objects.
- **Executable wiring:** The executable exists, has valid JSON, has a tiny prompt, and loads at least one skill unless it is deterministic.
- **State model:** The capability does not define raw state keys or require the author to paste a state block. Runtime state belongs to the engine.
- **No command recipe in capability:** Bash, `gh`, Python, and long step-by-step logic belong in executable skills or executable-owned scripts.
- **Output path:** Reports go under `reports/`; durable human guidance goes under `.kody/context/`; hidden cursors stay in runtime state.
- **Observed behavior:** For enabled capabilities, recent state/report/activity should roughly match the declared cadence. Disabled capabilities are reviewed for design only.
- **One-action limit:** The method should not spam many comments, issues, or commits in one tick unless the executable explicitly batches a report write.

## Allowed Commands

- `gh repo view`
- `gh api` reads for `.kody/capabilities`, `.kody/executables`, `reports/` in the configured Kody state repo, and state/history when available
- `gh issue list`, `gh issue create`, and `gh issue comment` only for the Kody capability review tracking issue

## Restrictions

- Read-only on reviewed capabilities and executables.
- Do not fix the capability being reviewed.
- Do not re-kick or relabel work.
- One reviewed capability per tick.
- One tracking issue comment at most per tick.
