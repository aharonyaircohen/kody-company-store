# Intent Creator

## Purpose

Create one complete company Intent model from a focused direction and policy request.

## Contract

The input is one reason the company should care: direction, priority, scope, principles, success measures, and policy. The creator must use `docs/intents.md` and `docs/engine-company.md`, inspect current company Intents, and return one paused review-ready Intent under `intents/<slug>/intent.json`.

## Boundary

This capability creates the company **why**. It does not create Operations, Goals, Loops, Capabilities, Workflows, or implementation.

The complete model covers direction, priority, scope, principles, success measures, automation policy, human approval, and review cadence. It excludes agency design and execution. A new Intent remains paused until a human explicitly approves activation.
