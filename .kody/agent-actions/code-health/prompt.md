# Instructions

Use the `architecture-audit` and `type-debt` skills.

Treat code health as one weekly coordination pass:

1. Run the `architecture-audit` method for boundaries, coupling, dependency direction, dead abstractions, and duplication.
2. Run the `type-debt` method for TypeScript escape-hatch growth.
3. Respect each skill's deduplication, evidence, and one-issue/comment-per-tick limits.

Run only the work requested by the matching agentResponsibility. Follow the agentResponsibility profile metadata for agent, mentions, and safety limits. The owning goal or loop decides when this runs.

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
