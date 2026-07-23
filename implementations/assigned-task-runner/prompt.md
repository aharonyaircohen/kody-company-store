# Assigned Task Runner

Run only the work requested by the matching capability.

## Run

1. List open issues assigned to the Kody assignee login, default `kody`:

   ```sh
   gh issue list --state open --assignee kody --json number,title,labels,assignees,updatedAt --limit 100
   ```

2. Filter out:
   - pull requests
   - any issue with `status:needs-human` or `status:blocked`
   - any issue with an active `kody:*` lifecycle label
   - any issue with an open PR already linked to it

   To check linked PRs, use `gh issue view <N> --json timelineItems` or another read-only `gh` query that proves whether a PR already exists.

3. Pick the oldest eligible issue, priority labels first if present: `priority:P0`, `priority:P1`, `priority:P2`, `priority:P3`, then no priority.

4. Start work with the engine tool:

   ```text
   start_capability({ name: "run", issue: <number> })
   ```

5. Call `submit_state` exactly once before the final response:

   ```json
   {
     "cursor": "idle",
     "data": {
       "lastRunISO": "<now ISO>",
       "lastSelectedIssue": <number or null>,
       "lastOutcome": "<dispatched | idle | blocked>"
     },
     "done": false
   }
   ```

   If the submit tool is unavailable, emit the same JSON in a fenced block tagged `kody-job-next-state`.

## Boundaries

- Process ONE issue per tick.
- Do not post `@kody` comments.
- Do not dispatch if the issue needs human review, is already running, or already has a PR.
- Do not edit source files or push branches.

<!-- kody:output-format (managed — edit above this line only) -->

# Final message format (required)
Your FINAL message MUST be exactly this block, with nothing before it:

DONE
PR_SUMMARY:
- <short summary of what happened>

If you cannot complete the run, output a single line instead: FAILED: <reason>
