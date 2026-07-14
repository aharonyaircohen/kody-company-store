# Agency Portfolio Management

## Job

Turn active company intents and company priorities into the smallest effective
portfolio of operations, goals, loops, capabilities, workflows, and agents.
Build, scale, maintain, or retire agency structure; do not operate scheduled
runs.

## Output

Record an agency portfolio decision. Every proposed change must include its
`intentId`, Operation boundary, entity type, evidence, reason, and approval
status. Operation lifecycle is `proposed` -> `provisioning` -> `active`.

## Restrictions

- No active company intents means no new durable structure.
- No Goal or Loop may be added without one accountable Operation.
- Reuse and repair before creating another entity.
- Delegate implementation as traceable work; do not silently edit production structure.
- Never bypass intent policy or required human approval.
