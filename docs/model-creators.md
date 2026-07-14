# Agency Model Creators

The agency owns its structure. Model creation is split across five focused
capabilities; there is no central factory.

## Shared creation flow

Every creator must:

1. Read the focused operator request.
2. Inspect the current agency models and references.
3. Reuse existing models, skills, scripts, and conventions when they fit.
4. Create exactly one model of its own type.
5. Return complete review-ready files in `PR_SUMMARY.files`.
6. Pass the engine's generic model-proposal validation.
7. Open a review PR in the configured state repo without activating the model.

The creator must fail with the specific missing decision when the request is
too ambiguous to produce one valid model. It must not guess across model
ownership boundaries.

## Agent creator

`agent-creator` creates the agency's **who**.

It defines identity, judgment, priorities, and hard behavioral boundaries. It
must not define tasks, schedules, tools, capability interfaces, workflow steps,
goal evidence, or loop cadence.

Output: `agents/<slug>.md`.

## Capability creator

`capability-creator` creates one reusable **how**.

It defines one `observe`, `act`, or `verify` ability; inputs and outputs;
allowed and forbidden actions; and any required implementation profile,
prompt, skills, tools, or scripts. It must search for reusable implementation
parts before creating new ones and validate every referenced part.

It must not own agent identity, goal progress, loop cadence, workflow order, or
the identity of the requester.

Output: `capabilities/<slug>/profile.json`, `capability.md`, and only the
additional colocated implementation files the ability requires.

## Goal creator

`goal-creator` creates the durable **what**.

It defines the outcome, ordered evidence, allowed capabilities, facts,
blockers, evidence routing, and completion rules. Every evidence item must be
testable and every capability reference must exist.

It must not define capability implementation, agent identity, loop cadence, or
workflow internals.

Output: `goals/templates/<slug>/state.json`. It creates a reusable template,
not a live runtime instance.

## Loop creator

`loop-creator` creates the **when**.

It defines cadence, wake policy, wake target, cursor, deduplication, and retry
behavior. The wake target must reference one existing goal, workflow, or
capability.

It must not decide business completion, goal evidence, workflow order,
capability implementation, or agent identity.

Output: one shared loop template or state definition under the current
goal/loop state model.

## Workflow creator

`workflow-creator` creates composed **how for one run**.

It defines ordered capability calls, input/output handoffs, failure rules, and
the final run output. Every capability reference must exist. A workflow must
not be created when one capability is enough.

It must not own long-term progress, schedule, goal completion, agent identity,
or capability implementation internals.

Output: a capability profile with a `workflow.steps` contract under
`capabilities/<slug>/profile.json`.

## Cross-model changes

When one request requires several model types, the agency uses an ordinary
workflow to call the required creators in dependency order. The workflow owns
only the order and handoffs. Each creator still produces and validates exactly
one model.

Creating a brand-new agency is a bootstrap/template concern. It is not a
permanent factory capability inside the engine or Store.
