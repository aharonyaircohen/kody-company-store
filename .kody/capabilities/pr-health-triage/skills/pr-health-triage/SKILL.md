---
name: pr-health-triage
description: Review open PRs for conflicts, failed CI, or stale branches, then recommend the next safe repair.
---

# PR Health Triage Skill

Use this skill when the `pr-health-triage` executable runs from the matching capability.

Runtime state is owned by the engine. Do not ask the capability author to configure raw state keys.

## Method

> Standing PR-health triage, executed by the **CTO** agent
> (`agent: cto`). Every 15 minutes, read the open pull requests, detect
> which ones need a mechanical repair, and recommend the next safe repair
> to the operator. Schedule is enforced by the owning goal/loop; no prose
> skip guard is needed.

## Job

Each tick, look at every open PR, pick at most one repair per PR (by the
priority order below), and recommend it. The CTO agent identity defines only
_who_ runs this; all authority, scope limits, and comment formats below belong
to **this job**.

## Tick procedure

Run the PR triage through the capability tools only. Keep it deterministic: one
PR list, one optional trust-ledger read, and at most one recommendation per PR.
Use runtime state only as a dedup ledger so the same recommendation does not
re-fire on every tick.

## State

State is only a dedup ledger. Keep one canonical shape:

```json
{
  "cursor": "idle",
  "data": {
    "lastOutcome": "completed",
    "lastFiredAt": "<ISO timestamp>",
    "lastDurationMs": 0,
    "recommendations_posted": ["<pr>-<verb>"]
  },
  "done": true,
  "version": 1
}
```

Treat older `data.recommendations` entries like `{ "pr": 252, "verb": "resolve" }`
as already-posted fingerprints, but always write the canonical
`data.recommendations_posted` array in the final state. Do not write
`data.recommendations`.

## Authority — the trust ledger

This job is **advisory only**. It never dispatches repairs directly.

- Use `recommend_to_operator` for every new repair recommendation.
- You may call `read_ledger` for context, but never hand-roll trust decisions
  or comments outside the provided tools.
- Repair dispatch belongs to the dedicated repair capabilities after the
  operator confirms the recommendation.

## Scope (hard limits)

- The only repair actions this job may ever recommend are `fix-ci`, `sync`,
  and `resolve`.
- No `merge`, `approve`, `execute`, `qa-review`, `close`, `revert`,
  `abort`, assign, or label — entirely out of scope here.
- Never edit, create, or delete any file in the working tree. Never
  `git commit`, `git push`, open a PR, run a repair, or trigger a repair
  workflow. The only write paths are `recommend_to_operator` and
  `submit_state`.

### Enumerate

Call `list_prs_to_repair` once. It returns open, non-draft PRs with repair
signals. Do not call `gh pr list`, do not paginate, and do not inspect PRs one
by one.

### Read the trust ledger (do this first, every tick)

Use `read_ledger` only if you need operator-trust context for the final
summary. It does not grant this capability repair-dispatch authority.

### Detect the repair (priority order — first match wins, one per PR)

For each returned PR, evaluate in this exact order, stop at first hit:

1. **Conflicts → `resolve`.** `mergeable === "CONFLICTING"`.
2. **CI failed → `fix-ci`.** `ciStatus === "FAILING"`.
3. **Stale branch → `sync`.** Only if neither of the above. Measure drift:
   `behindBy > 10` → `sync`. `<= 10` → leave alone (small drift is normal).

No hit on any of the three → leave the PR alone this tick.

### Recommend the repair

Let `<verb>` be the detected primitive and `<n>` the PR number.

- Call `recommend_to_operator` once for that PR.
- The recommendation body must not include an operator mention. The tool
  prepends the operator handle. Include the inert `kody-intent` line in the
  body.
- Still honour the dedup ledger: never auto-run or recommend the same repair on
  the same PR twice for the same fingerprint.

## Comment formats

**Operator handle.** Never type `{{mentions}}` and never hardcode a handle.
`recommend_to_operator` prepends the operator mention.

**Recommendation.** One terse, machine-greppable comment. The final posted
comment must mention the operator on the first line, but the agent-supplied
body must not include that mention because `recommend_to_operator` prepends it.
The body must carry the recommended action on a single inert `kody-intent` line.
This line must not include the engine command handle; the Dashboard can turn
the intent into an engine command only after an explicit operator approval:

```
🧭 **CTO recommendation** — `<verb>`

<one or two sentences: what's wrong with PR #<n> and what confirming will do>

<!-- kody-intent: <verb> --pr <n> -->

_Confirm or dismiss this in the dashboard inbox. The CTO will not act on its own._
```

## Allowed Tools

- `list_prs_to_repair` — the single enumeration call.
- `recommend_to_operator` — Ask-mode recommendation comments.
- `read_ledger` — optional context only.
- `submit_state` — required final state write.

## Restrictions

The **Scope (hard limits)** section above applies in full. In addition,
per-tick:

- One recommendation per PR per tick, and only when the repair is **new**
  (fingerprint changed — see State). Re-posting every 15 minutes is the
  primary failure mode; the dedup ledger prevents it.
- Never use Bash or `gh`.
- Never call `fix_ci_pr`, `sync_pr`, or `resolve_pr` from this capability.
- Never include `{{mentions}}` in comment bodies.
- Never include the literal engine command handle anywhere in the posted
  recommendation. An executable command inside a GitHub comment self-triggers
  the `issue_comment` workflow.

## Final State

Before the final `DONE` message, emit exactly one fenced JSON block labelled
`kody-job-next-state` with the canonical state shape from **State**. Include all
previously posted fingerprints and any new recommendations from this tick.
