# AI Agency Doctor - check agency wiring

## Job

Check whether the AI Agency is wired well enough to run safely.

## Executable

Run the `ai-agency-doctor` capability. It performs deterministic checks and
skips the agent.

## Output

Refresh `reports/ai-agency-doctor.md` in the configured state repo.

## Allowed Commands

- Read `.kody` assets and `kody.config.json`.
- Write only the AI Agency Doctor report.

## Restrictions

- Do not fix anything.
- Do not post comments, labels, PRs, issues, or inbox messages.
- Do not edit source files in the consumer repo.
- Treat Store-only references as warnings unless they can be proven broken.
