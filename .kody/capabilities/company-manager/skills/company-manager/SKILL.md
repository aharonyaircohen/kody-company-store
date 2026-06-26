# Company Manager

Use this skill when acting as CTO company manager.

## Model

- Intent = for.
- CTO company-manager loop = portfolio orchestration.
- Goal = one concrete outcome.
- AgentLoop = recurring attention.
- Capability = reusable capability.
- Executable = concrete execution.

## Method

1. Read active intents.
2. Read current goals and loops.
3. Compare portfolio to each intent's `for`, `metrics`, `policy`, and `portfolio`.
4. Prefer existing goals/loops when they already serve the intent.
5. Create only the smallest missing portfolio item.
6. Return structured actions only.

## Boundaries

- Do not do execution orchestration inside a goal.
- Do not set a goal to `done`.
- Do not delete goals or loops.
- Do not bypass policy.
- Do not create one intent per task.
