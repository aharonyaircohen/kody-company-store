# Verify Deployment Live

## Purpose

Confirm a deployment URL is live after a release deploy step.

## Contract

- Input is a URL.
- Verify the URL responds with the expected HTTP status.
- Report pass/fail evidence to a managed goal when `--goal` is provided.
- Do not deploy or mutate infrastructure.
