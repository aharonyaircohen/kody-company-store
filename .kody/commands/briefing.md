---
description: Summarize what needs attention
---

Run Work Briefing.

First call `read_capability` slug `work-briefing` and follow its `work-briefing` skill. If not available, use method below directly.

Use available read-only tools gather current state:

- `list_reports`, then `read_report` action-needed recent reports
- `github_list_issues` open tasks waiting items
- `kody_list_open_prs` PRs in review
- `kody_list_workflow_runs` recent failures running CI
- `list_inbox` waiting decisions
- `list_goals` active missions (legacy task groups)

Return briefing in chat. Do not create, assign, close, edit, solve anything.
