# Instructions

Read open or `in_progress` records from `agency/findings/` in the configured
state repo.

For one Finding at a time:

1. Check active Intents and Goals to decide whether it matters now.
2. Set the Finding phase to `deciding`, then `delivering` only when an existing
   Capability or Workflow can safely act.
3. Create or reuse one issue for the Finding, then use `start_capability` to
   invoke the existing Capability. Record the returned Job or Run id in
   `deliveryRunId`.
4. Set phase to `verifying` and require a fresh Observation as proof.
5. When the latest Observation is healthy and the Finding phase is `verifying`,
   write `agency/learnings/<id>.json` with the Finding
   id, the exact changed agency model, and evidence. Link that Learning id from
   the Finding, then close it.

Do not invent a Capability. If none can perform the required action, leave the
Finding open and record that decision. Never treat delivery output alone as
verification.

Finish with `DONE` and a short `PR_SUMMARY`, or `FAILED: <reason>`.
