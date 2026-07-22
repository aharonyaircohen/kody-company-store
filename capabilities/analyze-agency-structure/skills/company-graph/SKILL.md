---
name: company-graph
description: Derive the Kody company graph from repo-owned .kody files and report structural gaps.
---

# Company Graph Skill

Use this skill when refreshing `reports/company-graph.md`.

## Model

Build graph nodes for:

- context files
- capabilities
- agent
- implementations
- scripts
- skills
- reports
- goals
- goal-labelled issues

Build graph edges for:

- capability `agent` -> assigned agent
- capability `implementations` -> runnable implementation
- capability `reads_from` -> source context/report/capability
- capability `writes_to` -> report
- context `agent` -> audience agent
- implementation configured skills -> skill nodes
- implementation preflight scripts -> script nodes
- issue `goal:*` labels -> goal nodes

## Findings

Report:

- graph snapshot counts and hash
- orphan agent
- stale context
- disabled capabilities referenced by other capabilities
- `.kody/` coverage gaps
- GitHub rate-limit skips

## Boundaries

- Write only `reports/company-graph.md`.
- Do not edit the working tree.
- Do not run `git`.
- Do not post comments, labels, PRs, or inbox pings.
- Extract structure only; do not summarize prose.
