# Agency Model Playbook

Use this playbook to decide how the AI agency should be structured.

## First Principle

The agency grows from intent, not from available automation.

```text
Intent -> Agency Architect judgment -> smallest durable structure -> link back
```

Kody is the agency ecosystem and source of truth. Agency data must be stored and
resolved through Kody-owned state, store, vault, variables, goals, loops,
context, reports, and capability state. External env, GitHub secrets, CI runner
variables, and third-party config are bootstrap or transport only; they are not
company memory.

Every durable agency object should have a clear answer to:

```text
Which intent does this serve?
What responsibility does this model own?
What would break if this object disappeared?
```

Prefer no new structure when the need is vague, temporary, already covered,
too small, or not yet proven stable.

## Model Routing

Use this order before creating anything:

1. Is this only human direction? Keep it as an intent.
2. Is there a concrete result that should become true? Use a goal.
3. Does it need recurring attention? Use a loop.
4. Does it require a reusable ability? Use or propose a capability.
5. Does it require several capabilities chained in a repeatable run? Use or
   propose a workflow.
6. Does it require a distinct judgment identity? Use or propose an agent.
7. Does it require durable facts? Use or propose context.
8. Does it require different chat/interaction behavior? Use or propose
   instructions.
9. Is it only runtime progress or evidence? Use state.
10. If none apply, record a note.

## Intent

Intent owns why Kody should care.

Required properties:

- `id`: stable slug.
- `for`: plain-language direction.
- `description`: optional deeper context, nuance, constraints, examples, and
  what good looks like.
- `status`: active, paused, or archived.
- `priority`: ordering signal.
- `posture`: behavior preference.
- `scope`: where the direction applies, when truly needed.
- `principles`: rules to preserve.
- `metrics`: signals for whether the intent is being served.
- `policy`: safety and automation limits.
- `portfolio`: links to goals, loops, and capabilities that carry the intent.

Create or update intent when:

- A human gives durable direction.
- The one-line direction is not enough to preserve nuance.
- A priority changes.
- A policy or behavior preference changes.
- Existing agency structure no longer reflects what the human cares about.

Do not use intent for:

- One task.
- A route.
- A schedule.
- A capability name.
- Low-level execution steps.

Description rules:

- Keep `for` short enough to scan.
- Put deeper explanation in `description`.
- Use `description` to interpret the intent, not to override posture, policy,
  or portfolio links.
- Do not create new agency structure only because the description is long; the
  need still must be stable and useful.

Good intent examples:

- `Keep important PRs from going stale.`
- `Keep release work safe and evidence-backed.`
- `Keep product QA trustworthy before user-facing changes ship.`

Bad intent examples:

- `Run QA every day.` This is a loop request.
- `Use qa-engineer.` This is implementation.
- `Fix issue 123.` This is a task.

## Goal

Goal owns what should become true.

Required properties:

- Stable id.
- Linked intent.
- Concrete outcome.
- Evidence that proves completion.
- Current lifecycle state.
- Progress or stage.
- Blockers.
- Capabilities needed to reach the outcome.
- Route or plan when multiple steps are needed.

Create a goal when:

- The intent implies a concrete destination.
- Progress needs to be tracked over time.
- Evidence is needed before the work can be considered done.
- Several tasks should roll up to one outcome.

Do not create a goal when:

- The need is only recurring attention.
- The ask is only a one-off task.
- The outcome cannot be stated.
- An existing active goal already covers it.

Good goal:

```text
Outcome: Release PRs have evidence that build, QA, and publish readiness are clear.
Evidence: release PR exists, checks are green, QA verdict is recorded.
```

Bad goal:

```text
Outcome: Check releases every day.
```

That is a loop.

Lifecycle rules:

- Create active goals only when the outcome is clear.
- Close goals when the outcome is satisfied or no longer serves the intent.
- Abandon goals when the intent changed or the goal was the wrong structure.
- Do not delete goals; preserve history.

## Loop

Loop owns when to check again.

Required properties:

- Stable id.
- Linked intent.
- Cadence or trigger.
- Wake target: goal, capability, or review routine.
- Expected decision after each check.
- State showing last review and next useful action.

Create a loop when:

- The concern needs recurring attention.
- A goal or capability must be checked repeatedly.
- The value comes from ongoing review, not one final outcome.

Do not create a loop when:

- A one-time goal is enough.
- There is no useful decision to make on each tick.
- The cadence exists only because automation is available.

Good loop:

```text
Every day, inspect important open PRs and recommend action when one is stale.
```

Bad loop:

```text
Every day, do random cleanup.
```

Lifecycle rules:

- Pause loops when their intent is paused.
- Close loops when the recurring need is gone.
- Split loops when one cadence starts covering unrelated concerns.

## Capability

Capability owns reusable how.

Required properties:

- Stable id.
- Kind: observe, act, or verify.
- Public purpose.
- Inputs.
- Outputs.
- Safety rules.
- Owner or running identity.
- Execution binding.
- Tools or data it needs.

Use an existing capability when:

- It can produce the needed result safely.
- Its input/output contract fits.
- The intent does not require a new reusable ability.

Propose a new capability when:

- The same ability will be reused across goals or loops.
- Existing capabilities cannot observe, act, or verify the needed thing.
- The capability has a clear contract independent of one parent goal.

Do not create or propose a capability when:

- The work is one task.
- The need belongs inside a goal route.
- The capability would contain agency direction, identity, or long-term progress.

Good capability:

```text
Verify a PR preview against an expected user journey and return pass/fail evidence.
```

Bad capability:

```text
Make releases better.
```

That is intent or goal language.

## Workflow

Workflow owns composed how for one repeatable run.

Required properties:

- Stable id.
- Ordered steps.
- Capability used by each step.
- Inputs shared across steps.
- Outputs from each step.
- Final output contract.
- Failure behavior.

Use or propose a workflow when:

- A repeatable run needs multiple capabilities in a fixed order.
- The same step chain would otherwise be duplicated.
- The final result depends on intermediate outputs.

Do not use workflow for:

- Agency direction.
- Scheduling.
- Long-term progress.
- Agent identity.
- One-off improvisation.

Good workflow:

```text
Observe PR health -> sync branch if safe -> verify CI -> recommend next action.
```

## Agent

Agent owns who judges.

Required properties:

- Identity.
- Role voice.
- Values.
- Judgment style.
- Hard boundaries.

Create or propose an agent when:

- A distinct judgment style is required.
- Multiple capabilities or responsibilities need the same stable identity.
- The role is about how decisions are made, not what task is scheduled.

Do not put these in an agent:

- Task list.
- Schedule.
- Output schema.
- Tool recipe.
- A specific domain workflow.

Good agent:

```text
QA is skeptical, evidence-driven, and cares about user-visible correctness.
```

Bad agent:

```text
QA walks the changelog every day and posts a report.
```

That belongs in a loop or workflow.

## Context

Context owns durable background facts.

Required properties:

- Stable topic.
- Facts that help Kody reason.
- Scope of applicability.
- Source or owner when known.

Use context when:

- The same fact is needed across many decisions.
- The fact is not already obvious from repo files.
- The fact is background, not policy or scheduled work.

Do not use context for:

- Source-of-truth policy.
- A task.
- A loop.
- A prompt style rule.
- Runtime state.

Good context:

```text
This product uses GitHub as the only datastore; Vercel is only hosting.
```


## Instructions

Instructions own chat or interaction behavior.

Required properties:

- Behavior rule.
- Scope where the behavior applies.
- Examples when ambiguity is likely.

Use instructions when:

- Kody should answer differently.
- A surface needs stable response style.
- A command or chat mode needs interaction rules.

Do not use instructions for:

- Agency facts.
- Company structure.
- Scheduled work.
- Runtime progress.

Good instruction:

```text
Start with the answer, then give only the details needed to act.
```

## State

State owns what happened.

Required properties:

- Current lifecycle or status.
- Last update time.
- Evidence or log pointer.
- Pending next action, if any.

Use state when:

- A run happened.
- A goal advanced.
- A loop checked something.
- Evidence changed.
- A decision was recorded.

Do not use state for:

- Authoring rules.
- Desired future behavior.
- Portable doctrine.
- Human-owned intent text.

Lifecycle rules:

- Append or update state through the owning runtime path.
- Keep state out of source-of-truth docs.
- Do not hide structural decisions only in state.

## Relationship Rules

- Intent links to goals and loops that carry it.
- Goal may depend on capabilities.
- Loop may wake a goal or capability.
- Capability runs as an agent when judgment identity matters.
- Workflow chains capabilities for one run.
- Capability may read context and write reports or state.
- State records what happened; it does not define why work exists.

## Decision Output Rules

The current Agency Architect action contract can directly represent:

- `createManagedGoal`
- `createAgentLoop`
- `setGoalLifecycle`
- `updateIntentPortfolio`
- `note`

If the right structure is a capability, workflow, agent, context, instructions,
or unsupported state change, return a note that says:

```text
Missing model: <model>
Why this model is needed: <reason>
Why goal/loop is not enough: <reason>
Suggested next structural change: <short proposal>
```

Do not force unsupported models into goals or loops.

## Final Checklist

Before returning actions, check:

- Does every created object trace to an active intent?
- Is this the smallest useful structure?
- Did I reuse existing structure where possible?
- Is the model responsibility correct?
- Is the outcome or cadence clear?
- Is there evidence or a future decision point?
- Did I avoid one-off tasks becoming durable machinery?
- Did I link new goals or loops back to the intent?
