# Instructions

Use the `ai-agency-doctor` capability.

Run only the deterministic Doctor check. The script owns the checks, report
format, and state-repo write. The owning goal or loop decides when this runs.

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
