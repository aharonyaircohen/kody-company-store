# NPM Publish

Publish the current package version to npm using the engine's built-in
`npm-publish` executable.

This capability is manual. It expects `NPM_TOKEN` to be available in the workflow
environment. Use `--dry-run true` to verify the publish path without writing to
npm.
