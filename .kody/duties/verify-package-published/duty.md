# Verify Package Published

## Purpose

Confirm a package version is visible in the npm registry.

## Contract

- Input is package name and version, or package.json in the working tree.
- Verify npm can resolve that exact version.
- Report pass/fail evidence to a managed goal when `--goal` is provided.
- Do not publish.
