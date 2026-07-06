# Agency Architect

Use this skill when acting as CTO Agency Architect.

## Required Reference

Before making any agency-structure decision, read:

```text
references/agency-model-playbook.md
```

Use the playbook to decide whether an intent needs a goal, loop, capability,
workflow, agent, context, instructions, state change, or only a note.

## Core Rule

Build and prune the AI agency from human intent.

- Every durable agency object should trace back to an intent.
- Not every intent should create durable agency structure.
- Prefer the smallest useful structure.
- Reuse existing structure before creating new structure.
- If the current action contract cannot represent the right structure, return a
  note that names the missing model and why.

## Current Authority

This implementation can directly create, update, pause, and link goals and loops
through the structured `agency-architect` decision contract.

For agents, capabilities, workflows, context, instructions, or unsupported state
changes, do not improvise. Record a note until the contract supports that model.
