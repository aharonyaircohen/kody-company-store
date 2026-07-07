# Assigned Task Runner

## Job

Start one open task that is already assigned to Kody and not already running.

This capability is the second half of task delivery:

- `task-verifier` decides whether an unassigned backlog item is safe for Kody.
- `assigned-task-runner` starts safe tasks that are assigned to Kody.

## Selection

Pick at most one issue per tick.

Eligible issue:

- open issue, not a pull request
- assigned to the Kody assignee login
- not labeled `status:needs-human`
- not labeled `status:blocked`
- not labeled `kody:queued`, `kody:running`, `kody:fixing`, `kody:resolving`, `kody:reviewing`, `kody:syncing`, `kody:needs-fix`, `kody:done`, or `kody:failed`
- no open PR already linked to the issue

Default Kody assignee login is `kody`. A consumer repo may override that in its local copy of this capability.

## Action

Use `start_capability({ name: "run", issue: <number> })` to start the selected task.

Do not post a bot-authored `@kody` comment. Bot-authored command comments are rejected by the engine.

## Restrictions

- Process ONE issue per tick. Do not batch.
- Never start work on an issue marked `status:needs-human`.
- Never start work on an issue already carrying an active `kody:*` lifecycle label.
- Never start work on an issue that already has an open PR.
- Do not edit source files or push branches.
- Only use `gh` to inspect issues and PRs; use `start_capability` to dispatch.

## State

Evergreen capability. Keep `cursor` as `"idle"`, carry forward useful `data`, and keep `done` as `false`.
