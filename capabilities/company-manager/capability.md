# CTO Company Manager

## Job

Read active company intents and keep the agency portfolio aligned with them.

## Executable

Run `company-manager` executable. It loads active intents, current goals/loops, asks CTO for a structured portfolio decision, validates the decision, applies allowed changes, and records an intent decision log.

## Output

Update intent-linked goals and loops only through the structured company-manager decision contract.

## Allowed Commands

- Run `company-manager` executable.

## Restrictions

- Do not edit workflow YAML.
- Do not edit source code.
- Do not set a goal to `done`.
- Do not delete goals or loops.
- Do not bypass intent policy human-approval rules.
- Only create/update/pause/resume goals and loops through validated company-manager actions.
