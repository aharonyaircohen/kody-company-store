# Agency Director — Agency Portfolio Management

This capability is the Agency Director's portfolio-management action. It runs
as the COO identity and coordinates agency structure; it does not perform the
scheduled work owned by individual Operations.

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
- Delegate every new Operation contract to `operation-creator` as traceable work; do not author it here or silently edit production structure.
- Never bypass intent policy or required human approval.
