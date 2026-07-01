# Agent Factory

## Purpose

Create or assemble Kody agency model definitions from an operator request.

## Instructions

Use the `agent-factory` executable for model reasoning and state-repo PR creation.

The capability owns the public action name and the review boundary. The executable owns reading the request issue, producing the structured bundle, and opening the configured state-repo PR.

## Boundaries

- Do not create consumer-repo PRs for generated model definitions.
- Do not activate generated definitions directly.
- Do not bypass review by committing generated model files directly.
- Generated definitions must be proposed through the configured state repo.
