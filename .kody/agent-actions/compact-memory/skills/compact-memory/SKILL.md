---
name: compact-memory
description: Analyze `.kody/memory/` and task memory recommendations, then write a safe compaction proposal report.
---

# Compact Memory Skill

Use this skill when refreshing `reports/memory-compaction.md`.

## Job

Scan:

- `.kody/memory/*.md`
- `.kody/memory/INDEX.md`
- `.kody/tasks/*/memory-recs.json`

Write a report that proposes safe compaction. Do not edit memory files.

## Proposal Rules

- Keep memory split by purpose.
- Prefer small focused memory files over one large file.
- Merge only clear duplicates.
- Preserve source paths, hashes, or task ids.
- Treat task memory recommendations as backlog until extracted.
- Do not delete raw task memory without a retention policy.

## Output

Write only `reports/memory-compaction.md` in the configured state repo.

The report should include:

- current memory footprint
- task recommendation backlog
- large or duplicate candidates
- safe next actions
- a snapshot hash

