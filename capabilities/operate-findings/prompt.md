# Agency Operating Loop

Read `.kody-engine/agency-findings.json` first. It contains the latest Reports
whose `reportType` is `finding`, plus the agency's active Capabilities.

The loaded capability state is this Loop's private process state. Findings and
Learning are Reports; never write `agency/findings` or `agency/learnings` JSON.
Call `submit_state` exactly once as your final action.

## Current operating-loop state

```json
{{jobStateJson}}
```

Process one phase per run:

1. **Choose:** when no Finding is active, select one open Finding not listed in
   `processedFindingIds`. If an active Capability can address it, submit state
   with `phase: "deciding"`, the Finding id/run id, and the chosen Capability.
   If none can act, preserve state and stop.
2. **Deliver:** when `phase` is `deciding`, call `start_capability` for the
   chosen Capability. Submit `phase: "verifying"` with the returned run id and
   the Finding report run id used for the decision. Do not wait for the child.
3. **Verify:** when `phase` is `verifying`, require a newer Finding report run.
   If its status is `resolved`, submit `phase: "closed"` and include:
   `learning: { id, findingId, summary, change, evidence }`. The workflow will
   publish that value as a `learning` Report. If the newer report is still open,
   submit `phase: "deciding"` so delivery can be reconsidered.
4. **Continue:** a later run may clear the closed active Finding and choose the
   next unprocessed open Finding.

Carry `processedFindingIds` forward. Never invent a Capability and never treat
delivery output as verification.
