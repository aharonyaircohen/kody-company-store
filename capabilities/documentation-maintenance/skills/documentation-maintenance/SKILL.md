---
name: documentation-maintenance
description: Discover product surfaces from repo evidence and maintain a practical documentation plan using community documentation standards as the fixed baseline.
---

# Documentation Maintenance

Use this skill only when the `documentation-maintenance` implementation runs.

The goal is not to hard-code knowledge of any one product. The goal is to read the repo, infer what the product/system actually contains, and keep documentation coverage healthy.

## Fixed Standards

These are the only hard-coded checks:

- GitHub Community Standards: `README`, `LICENSE`, `CONTRIBUTING`, `CODE_OF_CONDUCT`, `SECURITY`, issue templates, PR template.
- Diataxis: tutorials, how-to guides, reference, explanation.
- Keep a Changelog: clear release/change history when the repo has releases or user-facing changes.
- Semantic Versioning: documented versioning rules when the repo publishes packages or releases.
- ADRs: architecture decision records for major non-obvious decisions.
- Docs-as-code: docs live in repo, get reviewed, and can be validated by CI where practical.

## Discovery Method

Read before claiming anything. Build a repo-specific map from evidence:

1. Identify repo kind and audience from `README`, package/build files, app entrypoints, deploy config, and docs.
2. Discover user-facing surfaces from routes, navigation config, command palettes, menus, CLIs, public APIs, implementation/capability definitions, and tests.
3. Discover developer-facing surfaces from API routes, service modules, auth/session code, data/storage layers, scripts, CI, env docs, and tests.
4. Discover operational surfaces from deployment config, webhooks, background jobs, schedulers, queues, secrets, monitoring, reports, and runbooks.
5. Inventory existing docs and map each doc to the surface/workflow/concept it explains.
6. Compare discovered surfaces to existing docs. Mark each as documented, thin, stale, missing, or unclear.

Never describe behavior unless you can point to files you read. If code and docs disagree, report drift instead of silently choosing one.

## Documentation Model

When recommending or drafting docs, organize by reader need:

- Overview: what this repo/product is, who uses it, and the mental model.
- Tutorials: first successful path for a new user/operator/developer.
- How-to: task-oriented workflows.
- Reference: APIs, configuration, commands, environment variables, routes, data contracts.
- Explanation: architecture, product model, tradeoffs, decisions, failure modes.
- Operations: deploy, verification, troubleshooting, incident/debug flow.
- Glossary: domain terms that appear across UI/code/docs.

Do not create a giant page because the product is large. Prefer a small book/table of contents with short linked chapters, and let the discovered product map choose chapter names.

## Per Run

1. Run a docs inventory.
2. Run a product/system discovery pass.
3. Identify the highest-value gap, stale section, or missing community-standard file.
4. Deduplicate against open documentation issues:
   - `gh issue list --state open --label kody:docs --json number,title --limit 50`
   - If label is missing, create it with `gh label create kody:docs --description "Kody: documentation maintenance"`.
5. Take one action:
   - If an existing issue covers the gap, add a concise evidence-backed comment.
   - Otherwise create one focused tracking issue.
6. Add one inbox recommendation comment that names the next operator-approved action.

## Issue Format

Use this shape for new tracking issues:

```text
Title: Documentation gap: <short discovered surface or standard>

## Finding
<one paragraph, grounded in files read>

## Evidence
- `<file>`: <what it shows>
- `<file>`: <what it shows>

## Recommended doc work
- <specific doc/chapter/file to add or update>
- <what reader question it should answer>

## Acceptance criteria
- <concise criteria>
- <docs link or validation command if available>
```

## Inbox Recommendation Format

Comment on the tracking issue with one terse recommendation. Mention operators on the first line.

```text
{{mentions}} DOCS: `<surface>` is under-documented or stale. Recommended next action: update `<doc target>` from the evidence above.
```

If the repo has a verified engine command for doc updates, include it as an HTML comment on one line. Verify the command exists before adding it.

## Restrictions

- Advisory only: do not edit files, commit, push, merge, or approve.
- Do not invent product structure or page names.
- Do not hard-code this repo's current routes/features into the skill.
- One focused issue/comment per run.
- Prefer evidence over breadth. If evidence is thin, ask for clarification in the issue.
- Skip generated, vendored, dependency, build output, runtime state, and secret files.
- Do not duplicate `docs-health` per-PR drift checks unless this run finds a broader handbook/product-map gap.
