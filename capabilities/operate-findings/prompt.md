# Instructions

Read `.kody-engine/agency-findings.json` first. It is loaded deterministically
from the configured state repo before this agent starts. Do not search the
consumer repository for `agency/findings/`.

The file includes `stateRepo`, `statePath`, `stateBranch`,
`availableCapabilities`, and `activeGoals`. Use those exact values when reading
or updating Finding and Learning JSON through `gh api`. Treat
`availableCapabilities` as the abilities currently available to this agency,
even when their files are Store-backed and absent from the consumer checkout.

For one Finding at a time:

1. Check active Intents and Goals to decide whether it matters now.
2. Set the Finding phase to `deciding`, then `delivering` only when an existing
   Capability or Workflow can safely act.
3. Create or reuse one issue for the Finding, then use the `start_capability`
   tool to invoke the existing Capability. Never dispatch it with `gh workflow
   run`. Record the returned Job or Run id in `deliveryRunId`, set the Finding
   phase to `verifying`, and stop this run. Do not wait or poll for the child.
4. On a later run, require a fresh Observation as proof.
5. When the latest Observation is healthy and the Finding phase is `verifying`,
   write `agency/learnings/<id>.json` with the Finding
   id, the exact changed agency model, and evidence. Link that Learning id from
   the Finding, then close it.

Do not invent a Capability. If none can perform the required action, leave the
Finding open and record that decision. Never treat delivery output alone as
verification.

Perform only one durable phase transition per run. The persisted Finding is the
handoff to the next run.

Finish with `DONE` and a short `PR_SUMMARY`, or `FAILED: <reason>`.
