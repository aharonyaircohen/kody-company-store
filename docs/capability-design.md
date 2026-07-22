# Capability Design

Capabilities are reusable actions. They should describe work that can be called
from more than one goal, loop, or workflow without inheriting that parent's
business purpose.

## The Boundary

```text
Goal      = why the business wants something
Loop      = when repeated work should run
Workflow  = which actions run, and in what order
Capability = one reusable action
Profile   = the executable contract for that capability
```

A capability may use scripts, tools, or agent judgment. It does not need to be
a small shell helper. It does need one stable action boundary that remains
useful outside its first business use case.

## Name The Action

Prefer verb-object names that state what the capability does:

- `build-knowledge-graph`
- `read-ci-status`
- `publish-report`
- `verify-deployment`

Avoid names that mainly describe the first parent process:

- `company-growth-graph`
- `daily-release-step`
- `agency-loop-helper`

Do not put a vendor in the public capability name unless the vendor-specific
behavior is the contract. For example, `build-knowledge-graph` can use Graphify
today and a different implementation later. A capability named
`deploy-to-vercel` is correctly vendor-specific because deploying to Vercel is
the action itself.

## Reuse Before Composition

When two business processes need the same technical action, they should call
the same capability with domain inputs. Do not copy its scripts into a second
capability.

If several actions must run together, compose them in a workflow. If the work
must repeat, a loop schedules the workflow or capability. If evidence must
reach an outcome, a goal owns that progress.

```text
Knowledge System stays current (loop)
  -> build-knowledge-graph (capability)

Codebase health improves (goal)
  -> inspect repository (capability)
  -> build-knowledge-graph (same capability)
  -> review findings (capability)
```

## Capability Or Business Process?

Use a capability when all of these are true:

1. It performs one independently callable action.
2. Its inputs describe the work, not its parent goal or loop.
3. Its result reports neutral facts, evidence, or artifacts.
4. Another parent could reuse it without copying or renaming it.

Use a workflow, goal, or loop when the asset primarily owns:

- a business outcome
- an ordered chain of actions
- repeated cadence or scheduling
- progress, completion, or recovery decisions

## Duplication Rules

Do not add a capability when an existing capability already performs the same
action. Prefer, in order:

1. Reuse the existing capability unchanged.
2. Add a domain input when the action is the same but its subject differs.
3. Extract genuinely shared deterministic logic into engine shared scripts.
4. Create a new capability only when the action contract is meaningfully
   different.

A wrapper capability that copies another capability's scripts is not reuse. It
is duplicated implementation and should normally be a workflow.

## Review Questions

Before accepting a capability, ask:

1. What single action does its name promise?
2. Could two unrelated goals or loops call it?
3. Does it copy scripts or behavior from another capability?
4. Is it secretly scheduling or sequencing other actions?
5. Does it decide a business outcome instead of returning facts?
6. Would changing the parent business process force this capability to be
   renamed?

If the answer exposes parent ownership or copied mechanics, redesign the asset
before adding it to the Store.
