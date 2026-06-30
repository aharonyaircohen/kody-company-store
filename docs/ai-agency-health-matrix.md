# AI Agency Health Matrix

The AI Agency Health Matrix answers one repo-local question:

```text
Is this repo's AI agency healthy?
```

It is an observe-only report. It does not fix, install, promote, comment,
label, open PRs, or change runtime state beyond writing its own report.

## Model Boundaries

| Model | Owns | Must not own |
|---|---|---|
| Store | Shared reusable asset contracts and default templates | Consumer runtime state, repo-specific decisions, secrets, run history |
| Consumer repo | Activation choices in `kody.config.json` and local overrides | Store-wide defaults for other repos |
| State repo | Runtime goal instances, job state, reports, proof, run history | Shared catalog source |
| Agent | Identity only: who is acting | Schedules, methods, output formats, operational loops |
| Capability | One reusable observe, act, or verify behavior | Long-running progress or portfolio ownership |
| Goal / Loop | The desired outcome, cadence, route, and progress | Low-level scanning logic or repo-specific script details |
| Workflow | A multi-step chain of capabilities | The first primitive for a simple health question |

## Recommended Shape

Use the existing Store-owned `ai-agency-health` goal loop as the recurring owner.

```text
goal loop:  ai-agency-health
capability: ai-agency-health-matrix
output:     reports/ai-agency-health-matrix/runs/<timestamp>.md
```

The loop owns the recurring question and cadence. The capability owns the
deterministic inspection and report. Later action capabilities may consume the
report, but the matrix itself stays read-only.

The current `ai-agency-doctor` capability can be evolved into this matrix or
kept as a compatibility alias while consumers migrate. The target contract is
the matrix report, not the old broad "doctor" wording.

## Report Contract

Each run writes a markdown report with frontmatter and a structured JSON block.
The report should be stored in the configured state repo and state branch, under
the current repo's state path.

Required matrix columns:

| Column | Meaning |
|---|---|
| `area` | Store, config, agents, capabilities, goals, loops, jobs, operators, proof, overrides |
| `expected` | What the repo declares or what the Store contract requires |
| `actual` | What was found from real files, state, logs, or API checks |
| `health` | `healthy`, `missing`, `unknown`, `failing`, `stale`, `not-relevant`, or `repo-local` |
| `proof` | File path, report path, PR, run, comment, timestamp, or exact reason |
| `owner` | Store, consumer repo, state repo, operator, or later action capability |
| `nextAction` | The smallest next action, or `none` |

Required summary fields:

```json
{
  "schemaVersion": 1,
  "repo": "owner/name",
  "generatedAt": "ISO-8601 timestamp",
  "status": "green | yellow | red",
  "counts": {
    "healthy": 0,
    "missing": 0,
    "unknown": 0,
    "failing": 0,
    "stale": 0,
    "repoLocal": 0,
    "notRelevant": 0
  },
  "rows": []
}
```

## Health Rules

- `healthy`: resolved, active when expected, and backed by fresh proof.
- `missing`: declared or expected, but not resolvable.
- `unknown`: cannot be proven from available sources.
- `failing`: proven broken by command, run, report, or state.
- `stale`: exists, but last proof is older than its freshness rule.
- `repo-local`: intentionally local to the consumer repo, not a Store defect.
- `not-relevant`: Store item does not apply to this repo.

Use `red` only for `failing` or critical `missing` rows. Use `yellow` for
`unknown`, `stale`, or unverified Store references. Use `green` only when every
required row is healthy or explicitly not relevant.

## Inputs

The capability may read:

- `kody.config.json`
- local `.kody` assets
- Store catalog assets resolved for the repo
- configured state repo files
- job state files
- existing reports
- GitHub issues, PRs, comments, workflow runs, and check state when needed for proof

It must not rely on memory or prior chat claims as proof.

## Outputs

The capability may write only:

```text
<state.path>/reports/ai-agency-health-matrix/runs/<timestamp>.md
```

It may print a short terminal summary. It must not mutate source, Store assets,
config, issues, PRs, labels, or comments.

## Delegation Path

The matrix creates decisions; it does not execute them.

Recommended later capabilities:

- `store-item-install`: enable a Store item in the current repo.
- `store-item-verify`: run one focused proof for an installed item.
- `store-item-repair`: fix the Store item when failure is shared.
- `store-item-promote`: install a verified item in a second repo.

Those are act or verify capabilities. They should be triggered by an operator,
a manager loop, or a later workflow, not by the matrix itself.

## When To Use A Workflow

Do not create a workflow for the first version. A workflow is appropriate only
after the observe capability is stable and the team wants an explicit chain:

```text
health matrix -> install candidate -> verify candidate -> repair Store -> promote to another repo
```

Until then, `ai-agency-health` plus `ai-agency-health-matrix` is the cleanest
shape.

## Store Update Rule

If the matrix finds a problem:

- Shared contract failure: fix the Store asset, run Store tests, then re-run the
  matrix in the consumer repo.
- Consumer-specific need: keep it local to the consumer repo.
- Runtime state problem: repair the state repo, not the Store.
- Missing activation: update the consumer repo config, not the Store.
- Unclear ownership: mark `unknown` and require operator decision.

## Promotion Rule

A Store item should be promoted from A-Guy-Web to A-Guy-Admin only after:

1. It is installed or resolvable in A-Guy-Web.
2. It has fresh proof in an A-Guy-Web matrix report.
3. Any shared Store changes are committed and tested in the Store.
4. A-Guy-Admin has its own matrix proof after installation.

Passing in Web is eligibility, not proof for Admin.
