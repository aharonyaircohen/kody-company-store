---
description: Research -> draft -> create GitHub issue
argument-hint: <title or short description>
---

Open GitHub issue for: $ARGUMENTS.

Follow research-plan flow - do NOT skip steps:

1. **Research first.** 3-5 tool calls (`github_search_code`, `github_get_file`, `github_blame`, `github_list_issues`) find affected files, symbols, prior art. Negative results count.
2. **Draft body** concrete `path:line` references, `requirements` (file paths + symbol names), `acceptanceCriteria` (testable bullets), `affectedArea` (paths), mandatory **Research notes** block in `additionalContext` (2-4 bullets summarizing what you searched what you found).
3. **Show me draft.** Wait explicit approval before calling matching `create_*` tool. No unverified paths or symbols.
4. **After issue created**, ask whether execute it with Kody. Only call `kody_run_issue(issueNumber, notes=<the plan>)` if confirm - never automatically.
