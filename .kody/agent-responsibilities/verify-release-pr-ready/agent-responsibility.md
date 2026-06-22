# Verify Release PR Ready

## Purpose

Confirm a release PR is ready for the next release step.

## Contract

- Input is a PR number.
- Verify the PR exists, is open, is not draft, and has no failing or pending checks.
- Report pass/fail evidence to a managed goal when `--goal` is provided.
- Do not merge or edit the PR.
