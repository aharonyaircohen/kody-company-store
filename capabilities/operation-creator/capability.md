# Operation Creator

## Purpose

Create one complete agency Operation model from a focused durable-responsibility request.

## Contract

The input is one responsibility justified by active Intents. The creator must use `docs/operations.md` and `docs/engine-company.md`, inspect current Operations and agency references, and return one proposed review-ready contract under `operations/<slug>/operation.json`.

## Boundary

This capability creates one durable **responsibility boundary**. It does not choose company direction, implement Capabilities, operate runtime work, or create the linked Goals and Loops.

The complete model covers responsibility, `doesNotOwn`, `intentIds`, accountable Goals and Loops, and lifecycle. A proposal may begin with empty Goal and Loop lists while provisioning work is reviewed; activation requires at least one. Shared Capabilities, Workflows, and Agents remain outside the Operation.
