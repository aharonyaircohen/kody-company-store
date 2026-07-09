---
name: dev-ci-health
description: Keep repo default branch CI visible and open a repair issue when the branch is red.
---

# Dev CI Health Skill

Use this skill when the `dev-ci-health` implementation runs from the matching capability.

Runtime state is owned by the engine. Do not ask the capability author to configure raw state keys.

## Method

Keep the repo default branch's own CI visible in Dashboard. Always open or reuse one
health tracking issue for `{{defaultBranch}}`; only open a repair issue and dispatch
`@kody run` when the branch is red and no repair is already in flight.

Why: `fix-ci` / `sync` / `resolve` all need a `--pr`, but the default branch has no PR — so a
broken default-branch build is invisible to PR-only health tools. The health issue keeps
the watcher visible; the repair issue routes the fix. Duplicates are impossible here:
`ensure_issue` is keyed and idempotent, so a re-tick reuses open issues instead of
creating more cards.

## Tick

1. **Ensure the visible health issue:**
   `ensure_issue({ key: "default-branch-ci-health-{{defaultBranch}}", title: "{{defaultBranch}} CI health monitor", body: <health body> })`
   - This issue is intentionally visible even when CI is green or pending.
   - Keep returned `number` as `healthIssue`.

2. **Mark the health issue as Dashboard-visible:**
   - Run `gh label create "kody:task" --color "0E8A16" --description "Kody task" --force`.
   - Run `gh issue edit <healthIssue> --add-label "kody:task"`.

3. **Read default branch CI:** `read_check_runs({ ref: "{{defaultBranch}}" })`.
   - `state` is `"GREEN"` -> comment on `healthIssue`, `submit_state`, and stop.
   - `state` is `"PENDING"` -> comment on `healthIssue`, `submit_state`, and stop.
   - `state` is `"RED"` -> keep `sha` and `failing` (each has `name` + `detailsUrl`), comment on `healthIssue`, and continue.

4. **Ensure the one repair issue (this IS the fix dedup):**
   `ensure_issue({ key: "default-branch-ci-red-{{defaultBranch}}", title: "{{defaultBranch}} CI is red — Kody auto-fix", body: <below> })`
   - If it returns `created: false`, a fix is already in flight -> `submit_state`
     and stop. Do **not** dispatch again.
   - If `created: true`, keep the returned `number` and continue.

5. **Mark the repair issue as Dashboard-visible:**
   - Run `gh label create "kody:fixing-ci" --color "1D76DB" --description "Kody is fixing CI" --force`.
   - Run `gh issue edit <number> --add-label "kody:fixing-ci"`.

   Health issue body:

   ```
   {{mentions}} `{{defaultBranch}}` branch CI health is being watched.

   This card stays visible so Dashboard shows the default-branch CI health tool even when CI is pending or green.

   When CI turns red, Kody opens or reuses the matching repair issue and tries to dispatch a fix.
   ```

   Repair issue body:

   ```
   {{mentions}} 🔴 `{{defaultBranch}}` branch CI is failing.

   - Commit: `<sha>`
   - Failing checks: <each failing name + its detailsUrl>

   Task: diagnose the failing check(s) and fix `{{defaultBranch}}` CI. This repo
   works directly on the default branch unless instructed otherwise. Keep it minimal; if a failure is flaky / scanner-config rather than a
   code defect, make the smallest change that helps — or none, and say so.
   ```

6. **Dispatch the fix:** `start_capability({ name: "run", issue: <number> })`.

7. **Notify once:** `ensure_comment({ issue: <number>, key: "default-branch-ci-red-{{defaultBranch}}:dispatched", body: "CTO auto-ran — dispatched @kody run (failing: <names>). The fix targets {{defaultBranch}} CI." })`.

8. **`submit_state`** with `{ cursor: "idle", data: {}, done: false }`.

The health issue (`key: "default-branch-ci-health-{{defaultBranch}}"`) is the always-visible Dashboard card because it carries a `kody:*` label.
The repair issue (`key: "default-branch-ci-red-{{defaultBranch}}"`) is the fix dedup — while it is open,
`ensure_issue` returns `created: false` and the capability stops before dispatching another fix.
