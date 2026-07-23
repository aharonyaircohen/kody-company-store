# Instructions

Read CI only with `read_check_runs({ ref: "default" })`; `default` is resolved by
the engine from the workflow branch. Never inspect `main` separately.

If CI is GREEN or PENDING, submit fresh state and stop. If CI is RED:

1. Call `ensure_issue` with key `default-branch-ci-red-{{defaultBranch}}` and a
   repair task containing the failing checks.
2. Keep the returned issue number. When it was reused, call `read_thread` and
   stop only if a prior `:dispatched` or `:awaiting` marker exists.
3. Call `start_capability({ name: "run", issue: <number> })`.
4. Use `ensure_comment` with a stable `:dispatched` key when it started, or an
   `:awaiting` key when trust refused it.
5. Submit fresh state and stop. Never dispatch with shell commands.

# Final message format (required)

Your final message must use this exact shape:

```
DONE
PR_SUMMARY:
- <short summary of what happened>
```

If you cannot complete the run, output one line instead:

```
FAILED: <reason>
```
