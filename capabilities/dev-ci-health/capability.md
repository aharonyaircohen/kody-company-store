# Branch CI health

Watch the repo default branch's own CI. If the check on `{{defaultBranch}}`'s tip is failing and no fix is already in flight, open a single repair issue and dispatch `@kody run` to fix it.

Why: `fix-ci`, `sync`, and `resolve` all need a `--pr`, but the default branch has no PR, so a broken default-branch build is invisible to PR-only health tools.

Duplicates are impossible here: `ensure_issue` is keyed idempotently, so a re-tick reuses one open repair issue instead of creating another.

## Tick

1. **Read default branch CI:** `read_check_runs({ ref: "default" })`.
   - Read only `{{defaultBranch}}`; do not inspect `main` or another branch.
   - If `state` is `"GREEN"` or `"PENDING"`, call `submit_state` with fresh `lastRunISO` and `nextEligibleISO`, then stop.
   - If `state` is `"RED"`, keep `sha` and `failing` (each `name` + `detailsUrl`), then continue.
2. **Ensure one repair issue (dedup):** `ensure_issue({ key: "default-branch-ci-red-{{defaultBranch}}", title: "{{defaultBranch}} CI is red - Kody auto-fix", body: <below> })`.
   - Keep the returned `number` whether `created` is true or false.
   - If `created: false`, call `read_thread` for that issue. Stop only when an
     existing comment contains the stable `:dispatched` or `:awaiting` marker;
     otherwise continue because a prior run may have stopped after creating the issue.
3. **Mark the repair issue as Dashboard-visible:** ensure label `kody:fixing-ci` exists with `gh label create "kody:fixing-ci" --color "1D76DB" --description "Kody is fixing CI" --force`, then run `gh issue edit <number> --add-label "kody:fixing-ci"`.

Issue body:

```md
{{mentions}} `{{defaultBranch}}` branch CI is failing.

- Commit: `<sha>`
- Failing checks: <each failing name + its detailsUrl>

Task: diagnose the failing check(s) and fix `{{defaultBranch}}` CI. This repo works directly on the default branch unless instructed otherwise. Keep it minimal; if the failure is flaky or scanner-config rather than a code defect, make the smallest helpful change, or none and say so.
```

4. **Try to dispatch fix:** `start_capability({ name: "run", issue: <number> })`.
   - Tool only fires when capability is trusted (Auto).
   - If the capability is in Ask mode, it dispatches nothing and returns a not-trusted refusal. Read result.
5. **Notify once, per outcome:**
   - **Dispatched (Auto)** -> `ensure_comment({ issue: <number>, key: "default-branch-ci-red-{{defaultBranch}}:dispatched", body: "CTO auto-ran - dispatched @kody run (failing: <names>). The fix targets {{defaultBranch}} CI." })`.
   - **Not dispatched (Ask)** -> `ensure_comment({ issue: <number>, key: "default-branch-ci-red-{{defaultBranch}}:awaiting", body: "{{defaultBranch}} CI failing (<names>). Awaiting operator - grant capability Auto on dashboard Trust page to auto-dispatch fix." })`.
   - Do not dispatch in Ask mode.
6. **Submit state** with:

```json
{
  "cursor": "idle",
  "data": {
    "lastRunISO": "<now ISO>",
    "nextEligibleISO": "<now + 15m ISO>"
  },
  "done": false
}
```

The repair issue (`key: "default-branch-ci-red-{{defaultBranch}}"`) is the whole dedup mechanism. While it is open, `ensure_issue` returns `created: false` and the capability stops. Closing it allows a later red tick to open a fresh one.
