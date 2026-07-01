# AI Agency Health Matrix

## Job

Answer whether the current repo's AI agency is healthy.

## Output

Write a timestamped matrix report under:

```text
reports/ai-agency-health-matrix/runs/<timestamp>.md
```

The report compares expected agency structure with actual repo, Store, and state
signals.

It must include architecture-boundary findings, especially whether reusable
capabilities are depending on parent goal or loop ids instead of returning
neutral results for the runner to attach.

## Allowed Commands

- Read `kody.config.json`.
- Read local `.kody` assets.
- Read Store catalog assets.
- Read configured state repo files when available.
- Write only the health matrix report.

## Restrictions

- Do not fix anything.
- Do not install Store items.
- Do not promote items to another repo.
- Do not post comments, labels, PRs, issues, or inbox messages.
- Do not edit source files in the consumer repo.
- Do not treat memory or prior chat claims as proof.
