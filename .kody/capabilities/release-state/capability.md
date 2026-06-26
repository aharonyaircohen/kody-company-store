# Release State

## Purpose

Observe the current release state without changing anything.

## Contract

- Read package version, release PR, tag, and optional package registry state.
- Return facts that a release goal can use to choose the next step.
- Do not create PRs, tags, releases, or deploys.

## Output

Facts such as current version, release PR number, release tag, and publish state.
