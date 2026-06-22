---
name: ceo-performance-review
description: Review every agent by the agentResponsibilities they own and the evidence those agentResponsibilities produce.
---

# CEO Performance Review Skill

Use this skill when the `ceo-performance-review` agentAction runs from the matching agentResponsibility.

Runtime state is owned by the engine. Do not ask the agentResponsibility author to configure raw state keys.

## Method

## Job

A **weekly review of every agent**, the way a company reviews its
employees. The unit is the **person** (`.kody/agents/<slug>.md`), not the
task — `agent-responsibility-review` (COO) grades whether each _duty_ is well designed;
this grades whether each _employee_ is actually **delivering the
responsibilities they own**.

An employee's "work" is the set of agentResponsibilities whose profile names them
(`"agent": "<slug>"`). Their delivery quality is read from the **evidence those
agentResponsibilities leave behind**: state files advancing on cadence, reports/comments
that aren't stale or empty, output that's useful rather than churn or noise.

This agentResponsibility cannot measure subjective taste or judge free-form prose quality —
it has no ground truth for "good." It measures the honest, observable thing:
**are this person's responsibilities getting done, on time, with real
output?** An agent who owns no active agentResponsibilities is reported as _idle_, not
graded.

Purely diagnostic: it never edits, re-kicks, or relabels anyone's agentResponsibilities.
**Output is a report file, not an inbox comment** — it overwrites
`reports/ceo-performance-review.md` in the configured Kody state repo each week, which the dashboard
Reports page surfaces. Past weeks live in that file's git history.

## Tick procedure (all agent, one report write)

Cadence is the `"every": "7d"` agentResponsibility profile value — the engine enforces it. Do **not**
add a prose "skip if within 7 days" guard (that duplicates the schedule and
has caused regressions). State is recorded only for the dashboard "next run"
readout and the week-over-week delta.

1. **Pin the repo.** `gh`'s default repo is not guaranteed here:

   ```
   REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
   ```

   For A-Guy this resolves to `A-Guy-educ/A-Guy`, default branch `dev`.

2. **Enumerate agent.** List every `<slug>.md` in `.kody/agents/`:

   ```
   gh api "/repos/$REPO/contents/.kody/agents" -q '.[].name'
   ```

   Drop non-`.md` files. Each remaining slug is one employee.

3. **Map agentResponsibilities to employees.** List the agentResponsibility folders and read each one's
   `profile.json.agent` value so you know who owns what:

   ```
   gh api "/repos/$REPO/contents/.kody/agent-responsibilities" -q '.[].name'
   ```

   For each `<agentResponsibility>/profile.json`, read `agent` and `disabled`. Group
   agentResponsibilities by owner. A agentResponsibility with `"disabled": true` is **owned but parked** —
   list it under the employee, but don't penalize the employee for its
   idleness (disabled is the operator's choice, not the employee's miss).

4. **Gather each employee's delivery evidence.** For every _active_ agentResponsibility
   they own:
   - **State history:** configured Kody state repo `agent-responsibilities/<slug>/state.json` history when available — is the agentResponsibility advancing roughly on its cadence, or frozen?
   - **Output:** any tracking issue the agentResponsibility posts to, or `reports/<slug>.md` in the configured Kody state repo — did it produce real findings this week, or is it stale/empty? Repeated byte-identical no-op comments count as **churn**, not delivery.

5. **Grade each employee** on three observable axes, each Low / Med / High:
   - **Delivery** — did their active agentResponsibilities actually run and produce output this week? (No active agentResponsibilities → _idle_, ungraded.)
   - **Consistency** — did state advance on roughly the promised cadence, or are runs missed / frozen?
   - **Signal** — is the output useful (real findings, advancing work) versus churn / empty no-ops / noise?
     Roll the three into a one-word **Grade**: `strong` / `steady` / `weak` /
     `idle`. When the signal is genuinely ambiguous, say so and grade
     `unclear` rather than guessing — an honest unknown beats a fabricated
     score.

6. **Build the report markdown.** Lead with an `# Kody Performance Review`
   H1, then a `_Cadence: weekly — delivery of owned responsibilities, not
subjective quality._` line (**no timestamp** — `lastRunISO` lives in
   state, not the body, so a no-change week produces a byte-identical
   report). Then:
   - A one-sentence headline at the highest level (e.g. "Three of six agent
     delivered this week; tech-writer and ux-designer produced no output.").
   - A scoring table, one row per employee:
     ```
     | Agent | Owned agentResponsibilities | Delivery | Consistency | Signal | Grade |
     |-------|-------------|----------|-------------|--------|-------|
     | qa    | 2 (1 active)| High     | Med         | High   | steady |
     ```
   - Below the table, at most one short line per employee that isn't
     `steady` or `strong`, naming the concrete miss and its effect
     (`- **qa-engineer — weak:** qa-sweep state frozen 9 days; no sweep ran. **Effect:** regressions ship unreviewed.`).
   - A closing delta versus `data.lastGrades` if present
     (`- Changes since last week: tech-writer steady→strong; coo strong→weak.`).

7. **Write the report** at the canonical path
   **`reports/ceo-performance-review.md` in the configured Kody state repo** via `gh api` (fetch the
   prior sha so the PUT overwrites in place):

   ```
   sha=$(gh api "/repos/$STATE_REPO/contents/$STATE_PATH/reports/ceo-performance-review.md" -q .sha 2>/dev/null || true)
   gh api -X PUT "/repos/$STATE_REPO/contents/$STATE_PATH/reports/ceo-performance-review.md" \
     -f message="chore(ceo-performance-review): refresh report" \
     -f content="$(printf '%s' "$REPORT_BODY" | base64)" \
     -f branch="<defaultBranch>" \
     ${sha:+-f sha="$sha"}
   ```

   `<defaultBranch>` is `dev` for A-Guy. **One PUT per tick** — never write
   more than once.

8. **Emit closing state** (schema below) as the very last thing in the reply.

## Allowed Commands

- `gh repo view` — pin the repo.
- `gh api` reads against `/repos/$REPO/contents/.kody/agents`,
  `/repos/$REPO/contents/.kody/agent-responsibilities`, individual agentResponsibility bodies, their
  state repo state files, state repo `reports/*`, and
  `/repos/$REPO/commits?path=...` for run history.
- `gh api -X PUT` against `reports/ceo-performance-review.md` in the configured Kody state repo **only** —
  to write the report. Permitted by the global agent-responsibility-tick contract.

## Restrictions

- **Read-only on every agent file, agentResponsibility, state file, PR, and issue.** The
  **only** write is the single PUT to
  `reports/ceo-performance-review.md` in the configured Kody state repo. Never edit, re-kick, relabel,
  or "fix" anyone's agentResponsibilities — surface it on the report; the operator decides.
- **One report write per tick.** Never open issues or post comments — this
  agentResponsibility has no inbox surface by design.
- **No timestamp in the report body.** `lastRunISO` lives in state, so an
  unchanged week is byte-identical (skip-PUT on no diff is free).
- **Measure delivery, not taste.** Grade only what the evidence shows
  (ran / produced / on cadence). Never claim an employee's output is
  "good" or "bad" in substance — claim their responsibilities were or
  weren't delivered.
- **Don't penalize disabled agentResponsibilities.** `disabled: true` is the operator's
  choice; list it, don't dock the owner for it.
- **Idle ≠ failing.** An agent who owns no active agentResponsibilities is _idle_
  (nothing to deliver), reported plainly, not graded `weak`.
- **Honest unknown over a fabricated score.** Weak or contradictory
  signal → grade `unclear` and say why.
