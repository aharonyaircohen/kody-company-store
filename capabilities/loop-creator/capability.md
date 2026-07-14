# Loop Creator

## Purpose

Create one Kody AgentLoop model from a focused wakeup request.

## Contract

The input is one cadence and wakeup need. The creator must use `docs/jobs-model.md`, `docs/engine-company.md`, and `docs/ledgers.md`; define cadence, target, and operational ledger needs; and keep business completion out of the loop.

## Boundary

This capability creates the when. It does not create who, what, or implementation how.

The complete model covers cadence, wake target, cursor, deduplication, and retry policy. It excludes business completion, goal evidence, workflow order, capability implementation, and agent identity.
