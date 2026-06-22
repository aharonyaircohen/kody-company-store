# Job Gap Scan

## Job

Once per day, run the local `job-gap-scan` agentAction tick:

```bash
bash .kody/agent-actions/job-gap-scan/tick.sh
```

The agentAction writes one advisory proposal report to `.kody/reports/job-gap-scan.md` and updates `.kody/agent-responsibilities/job-gap-scan.state.json`.

## Restrictions

- Advisory only.
- Never write a new agentResponsibility directly.
- Never re-surface a permanently rejected candidate.
- Respect the dismiss cool-off in agentAction logic.
