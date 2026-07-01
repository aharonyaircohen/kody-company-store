# Architecture Boundaries

This Store is a reusable company catalog. It should keep goals, loops,
capabilities, implementation profiles, agents, and runtime state separate.

## Core Rule

A reusable capability does not own its parent goal or loop.

The clean flow is:

```text
goal/loop runner owns parent context
runner dispatches capability with domain inputs
capability runs one reusable observe/act/verify action
capability returns neutral result facts
runner attaches the result to goal/loop evidence and persists progress
```

## Responsibility Matrix

| Model | Owns | Does not own |
| --- | --- | --- |
| Goal | Outcome, destination evidence, route, stage, blockers, completion | Concrete deploy/test/edit mechanics |
| Loop | Schedule, cursor, heartbeat, repeated operating cadence | One-off business completion |
| Capability | Reusable ability, public contract, allowed action shape | Parent goal id, parent stage, durable progress |
| Implementation profile | CLI inputs, tools, scripts, prompt, run-local result | Business outcome, route decision, long-term state |
| Agent | Professional judgment inside the assigned scope | Scheduler, persistence model, parent ownership |
| State repo | Runtime facts, reports, goal instances, logs | Shared catalog definitions |

## Inputs

Capability inputs should be domain inputs needed for the work:

- `--pr`
- `--branch`
- `--url`
- `--version`
- `--evidence`
- `--scope`

Do not add these to a normal reusable capability as core inputs:

- `--goal`
- `--loop`
- parent route
- parent stage
- destination outcome

Those values belong to the runner that selected the capability.

## Results

New capabilities should return neutral machine-readable output:

```text
KODY_CAPABILITY_RESULT={"version":1,"status":"pass","summary":"Production is live.","evidence":{"productionDeployed":true},"facts":{"productionUrl":"https://www.example.com"},"artifacts":[],"missingEvidence":[],"blockers":[]}
```

The result says what happened. The parent goal or loop decides what that means.

## Compatibility

Some existing Store capabilities still accept `--goal` or emit target-bearing
`KODY_CAPABILITY_REPORT` output. That is transitional compatibility behavior for
older runner plumbing.

Do not spread that pattern to new capabilities. When changing those capabilities,
prefer moving parent attachment into the goal or loop runner instead of adding
more parent-aware capability inputs.

## Review Checklist

Before adding or changing a Store asset, check:

1. Does this asset own one clear responsibility?
2. Is durable progress stored in a goal, loop, or state repo file instead of a capability?
3. Does the capability receive only domain inputs?
4. Does the implementation profile return facts/evidence instead of deciding parent completion?
5. Does the runner attach returned evidence to the active parent?
6. Is any `--goal` or target-bearing output clearly marked as compatibility?
