---
name: dev-ci-health
description: Watch the repo default branch CI and open or reuse one tracking issue when the branch is red.
---

# Dev CI Health Skill

Use this skill when the `dev-ci-health` implementation runs from the matching capability.

Runtime state is owned by the engine. Do not ask the capability author to configure raw state keys.

## Method

Watch the repo default branch's own CI. If a check on `{{defaultBranch}}`'s tip is failing **and no
fix is already in flight**, open the single tracking issue and dispatch
`@kody run` to fix it.

Why: `fix-ci` / `sync` / `resolve` all need a `--pr`, but the default branch has no PR — so a
broken default-branch build is invisible to PR-only health tools. This routes the repair
through a tracking issue. Duplicates are impossible here: `ensure_issue` is keyed and
idempotent, so a re-tick reuses the one open issue instead of creating another.

## Tick

1. **Read default branch CI:** `read_check_runs({ ref: "{{defaultBranch}}" })`.
   - `state` is `"GREEN"` or `"PENDING"` -> nothing to do. `submit_state` and stop.
   - `state` is `"RED"` -> keep `sha` and `failing` (each has `name` + `detailsUrl`), continue.

2. **Ensure the one tracking issue (this IS the dedup):**
   `ensure_issue({ key: "default-branch-ci-red-{{defaultBranch}}", title: "{{defaultBranch}} CI is red — Kody auto-fix", body: <below> })`
   - If it returns `created: false`, a fix is already in flight -> `submit_state`
     and stop. Do **not** dispatch again.
   - If `created: true`, keep the returned `number` and continue.

   Issue body:

   ```
   {{mentions}} 🔴 `{{defaultBranch}}` branch CI is failing.

   - Commit: `<sha>`
   - Failing checks: <each failing name + its detailsUrl>

   Task: diagnose the failing check(s) and fix `{{defaultBranch}}` CI. This repo
   works directly on the default branch unless instructed otherwise. Keep it minimal; if a failure is flaky / scanner-config rather than a
   code defect, make the smallest change that helps — or none, and say so.
   ```

3. **Dispatch the fix:** `start_capability({ name: "run", issue: <number> })`.

4. **Notify once:** `ensure_comment({ issue: <number>, key: "default-branch-ci-red-{{defaultBranch}}:dispatched", body: "CTO auto-ran — dispatched @kody run (failing: <names>). The fix targets {{defaultBranch}} CI." })`.

5. **`submit_state`** with `{ cursor: "idle", data: {}, done: false }`.

The reused issue (`key: "default-branch-ci-red-{{defaultBranch}}"`) is the entire dedup — while it is open,
`ensure_issue` returns `created: false` and the capability stops. The fix PR closes it
on merge; only then does a later tick open a fresh one.
