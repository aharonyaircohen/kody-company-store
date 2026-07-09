# Branch CI health

Keep the repo default branch's own CI visible in Dashboard. Always open or reuse one health tracking issue for `{{defaultBranch}}`; only open a repair issue and dispatch `@kody run` when the branch is red.

Why: `fix-ci`, `sync`, and `resolve` all need a `--pr`, but the default branch has no PR, so a broken default-branch build is invisible to PR-only health tools.

Duplicates are impossible here: `ensure_issue` is keyed idempotently, so a re-tick reuses the same open health issue and the same red repair issue instead of creating more cards.

## Tick

1. **Ensure one visible health issue (Dashboard card):** `ensure_issue({ key: "default-branch-ci-health-{{defaultBranch}}", title: "{{defaultBranch}} CI health monitor", body: <health body below> })`.
   - This issue is intentionally visible even when CI is green or pending.
   - Keep returned `number` as `healthIssue`.
2. **Mark the health issue as Dashboard-visible:** ensure label `kody:task` exists with `gh label create "kody:task" --color "0E8A16" --description "Kody task" --force`, then run `gh issue edit <healthIssue> --add-label "kody:task"`.
3. **Read default branch CI:** `read_check_runs({ ref: "{{defaultBranch}}" })`.
   - If `state` is `"GREEN"`, call `ensure_comment({ issue: healthIssue, key: "default-branch-ci-health-{{defaultBranch}}:green", body: "{{defaultBranch}} CI is green at `<sha>`." })`, then submit state and stop.
   - If `state` is `"PENDING"`, call `ensure_comment({ issue: healthIssue, key: "default-branch-ci-health-{{defaultBranch}}:pending", body: "{{defaultBranch}} CI is pending at `<sha>`." })`, then submit state and stop.
   - If `state` is `"RED"`, keep `sha` and `failing` (each `name` + `detailsUrl`), comment on `healthIssue`, then continue.
4. **Ensure one repair issue (dedup):** `ensure_issue({ key: "default-branch-ci-red-{{defaultBranch}}", title: "{{defaultBranch}} CI is red - Kody auto-fix", body: <repair body below> })`.
   - If it returns `created: false`, a fix is already in flight. Call `submit_state` with fresh `lastRunISO` and `nextEligibleISO`, then stop. Do not dispatch again.
   - If `created: true`, keep returned `number`, then continue.
5. **Mark the repair issue as Dashboard-visible:** ensure label `kody:fixing-ci` exists with `gh label create "kody:fixing-ci" --color "1D76DB" --description "Kody is fixing CI" --force`, then run `gh issue edit <number> --add-label "kody:fixing-ci"`.

Health issue body:

```md
{{mentions}} `{{defaultBranch}}` branch CI health is being watched.

This card stays visible so Dashboard shows the default-branch CI health tool even when CI is pending or green.

When CI turns red, Kody opens or reuses the matching repair issue and tries to dispatch a fix.
```

Repair issue body:

```md
{{mentions}} `{{defaultBranch}}` branch CI is failing.

- Commit: `<sha>`
- Failing checks: <each failing name + its detailsUrl>

Task: diagnose the failing check(s) and fix `{{defaultBranch}}` CI. This repo works directly on the default branch unless instructed otherwise. Keep it minimal; if the failure is flaky or scanner-config rather than a code defect, make the smallest helpful change, or none and say so.
```

6. **Try to dispatch fix:** `start_capability({ name: "run", issue: <number> })`.
   - Tool only fires when capability is trusted (Auto).
   - If the capability is in Ask mode, it dispatches nothing and returns a not-trusted refusal. Read result.
7. **Notify once, per outcome:**
   - **Dispatched (Auto)** -> `ensure_comment({ issue: <number>, key: "default-branch-ci-red-{{defaultBranch}}:dispatched", body: "CTO auto-ran - dispatched @kody run (failing: <names>). The fix targets {{defaultBranch}} CI." })`.
   - **Not dispatched (Ask)** -> `ensure_comment({ issue: <number>, key: "default-branch-ci-red-{{defaultBranch}}:awaiting", body: "{{defaultBranch}} CI failing (<names>). Awaiting operator - grant capability Auto on dashboard Trust page to auto-dispatch fix." })`.
   - Do not dispatch in Ask mode.
8. **Submit state** with:

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

The health issue (`key: "default-branch-ci-health-{{defaultBranch}}"`) is the always-visible Dashboard card because it carries a `kody:*` label. The repair issue (`key: "default-branch-ci-red-{{defaultBranch}}"`) is the fix dedup mechanism. While the repair issue is open, `ensure_issue` returns `created: false` and the capability does not dispatch another fix. Closing it allows a later red tick to open a fresh repair issue.
