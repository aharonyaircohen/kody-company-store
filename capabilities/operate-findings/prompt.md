# Instructions

Read `.kody-engine/agency-findings.json` first. It is loaded deterministically
from the configured state repo before this agent starts. Do not search the
consumer repository for `agency/findings/`.

The file includes `stateRepo`, `statePath`, `stateBranch`,
`availableCapabilities`, and `activeGoals`. Never write Finding or Learning JSON
with `gh api`. Use only `.kody-engine/agency-state.mjs` for durable state. Treat
`availableCapabilities` as the abilities currently available to this agency,
even when their files are Store-backed and absent from the consumer checkout.

For one Finding at a time:

- `observed`: decide, persist with `agency-state.mjs decide`, then stop.
- `deciding`: deliver with the existing Capability, persist with
  `agency-state.mjs deliver`, then stop.
- `verifying`: use only a newer Observation to resolve or reopen, then stop.

1. Check active Intents and Goals to decide whether it matters now.
2. When an existing Capability can safely act, persist the decision with
   `node .kody-engine/agency-state.mjs decide <finding-id> <capability> <reason>`.
3. Use the `start_capability` tool to invoke the existing Capability. Let that
   Capability own any issue it needs; the operating loop must not create a
   duplicate delivery issue. Never dispatch with `gh workflow run`. Pass
   `issue` only when that Capability's `availableCapabilities.inputs` declares
   an issue input; inputless Capabilities such as `dev-ci-health` must be started
   with only their name. Persist the returned Job or Run id with
   `node .kody-engine/agency-state.mjs deliver <finding-id> <run-id>`, then stop
   this run. Do not wait or poll for the child.
4. On a later run, require a fresh Observation as proof.
5. When the latest Observation is healthy and the Finding phase is `verifying`,
   run `node .kody-engine/agency-state.mjs resolve <finding-id> <observation-id>
   <changed-model> <summary>`. This writes Learning, links it, and closes the
   Finding at the agency state boundary.

Do not invent a Capability. If none can perform the required action, leave the
Finding open and record that decision. Never treat delivery output alone as
verification.

Perform only one durable phase transition per run. The persisted Finding is the
handoff to the next run.

Finish with `DONE` and a short `PR_SUMMARY`, or `FAILED: <reason>`.
