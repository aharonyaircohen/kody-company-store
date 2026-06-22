# Instructions

Use the `documentation-maintenance` skill.

Run only the work requested by the matching agentResponsibility. Follow the agentResponsibility profile metadata for cadence, agent, mentions, and safety limits.

# Final message format (required)

Your final message must use this exact shape:

```text
DONE
PR_SUMMARY:
- <short summary of what happened>
```

If you cannot complete the run, output one line instead:

```text
FAILED: <reason>
```
