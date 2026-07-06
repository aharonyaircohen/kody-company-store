---
name: qa-sweep
description: Run broad exploratory QA against the live app and summarize actionable findings.
---

# QA Sweep Skill

Use this skill when the `qa-sweep` implementation runs from the matching capability.

Runtime state is owned by the engine. Do not ask the capability author to configure raw state keys.

## Method

## Job

Periodic **broad exploratory QA** of the whole app — no scenario, no scope.
Delegates to the `qa-engineer` implementation with **no `--scope`**, so it smoke-tests
every discovered route against the live deployment, then summarizes the result
to the inbox. This catches regressions and rough edges in already-shipped
features that the changelog-verification capability (which only tests _new_ entries)
never revisits.

The target repo must define QA access context for `qa-engineer` before this
capability is enabled. Use `.kody/context/qa-access.md` or equivalent repo
context, and point to variables/secrets rather than raw secrets:

- `QA_URL` — live site/base URL.
- `LOGIN_USER` — QA account username.
- `LOGIN_PASSWORD` — QA account password secret.

**Per tick (one action max):**

1. Check for an open sweep tracking issue:
   `gh issue list --label "kody:qa-sweep" --state open --json number,title,createdAt,comments`
2. **Open, created < 2h ago** → emit `cursor: awaiting-result` and exit (sweep
   in flight; don't double-trigger).
3. **Open, with a `qa-engineer` report present** → post one inbox rec
   summarizing the sweep (verdict + finding count, links to the findings),
   close the tracking issue, clear `data.openIssue`.
4. **Open, ≥ 2h old, no report** → comment the stall, close it, clear state
   (the next eligible tick re-runs). A stuck sweep must never wedge the capability.
5. **Otherwise** (no active sweep is open) → open a tracking issue and
   dispatch with no scope through the engine capability tool. Do not run raw
   `gh workflow run`, and do not post a bot `@kody qa-engineer` comment;
   bot-authored command comments are rejected.
   ```
   gh issue create --title "QA sweep $(date -u +%Y-%m-%d)" --label kody:qa-sweep \
     --body "Automated broad QA sweep; qa-engineer reports here."
   start_capability({ name: "qa-engineer", issue: <n> })
   ```
   Set `data.openIssue = <n>` and `data.lastRunISO = now`.

## Inbox recommendation format

One comment, terse. It **MUST** `@`-mention the operator on the first line —
that mention is the only thing that routes it into the dashboard inbox:

```
{{mentions}} 🧹 **QA sweep** — `<action>`

<one or two sentences: routes covered, verdict, finding count>

<!-- kody-cmd: @kody qa-goal --issue <tracking> --scope "sweep" -->

_Confirm or dismiss in the dashboard inbox. QA will not act on its own._
```

`<action>` is `fix` when the sweep opened findings, or `note` for a clean
sweep. **On findings**, the `kody-cmd` is
`@kody qa-goal --issue <tracking> --scope "sweep"` — qa-engineer already posted
the sweep report on the tracking issue; on approve, `qa-goal` promotes it into
a fix goal (one ticket per finding). **On a clean sweep, omit the `kody-cmd:`
line** — it's informational; the operator just dismisses. **Never emit
`@kody approve`** — the engine has no `approve` verb. QA never creates the goal
itself; it's gated behind your approval.

## Allowed Commands

- `gh issue list`, `gh issue create`, `gh issue view`, `gh issue comment`,
  `gh issue close`.
- Engine tool: `start_capability({ name: "qa-engineer", issue: <tracking> })`.

## Restrictions

- **Advisory only.** Dispatching `qa-engineer` is read-only. Never merge,
  approve, fix, or label PRs yourself — surface, the operator confirms.
- **One sweep in flight**, and at most **one** issue action per tick.
- If `gh issue create --label kody:qa-sweep` fails because the label is missing,
  run `gh label create kody:qa-sweep --description "Kody: broad QA sweep"` and
  retry — the in-flight check depends on the label.
- All writes go through `gh` — never `git commit`/`git push`, never open a PR.
