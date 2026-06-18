# release-prepare skill

Prepare the version change.

## Owns
- Read current version from `package.json` or the closest project manifest.
- Apply the requested bump (`patch` by default).
- Update `CHANGELOG.md` with a dated release entry.
- Run the project test suite and linter.
- Create or reuse a release branch named `release/v<version>`.
- Open a version PR titled `chore(release): v<version>`.
- Put `Tracking-Issue: #<release issue number>` in the version PR body.
- After opening the PR, persist `<!-- kody-release-pr: #<PR number> -->` in the release issue body if it is not already present.

## Branch collision rules
Before creating `release/v<version>`, inspect all three states:

1. Local branch: `git show-ref --verify refs/heads/release/v<version>`
2. Remote branch: `git ls-remote --heads origin release/v<version>`
3. Existing PR: `gh pr list --head release/v<version> --state all`

Then apply:

- No local branch, no remote branch, no PR: create the branch from latest integration branch.
- Local branch exists, remote branch is gone, and no PR exists: treat it as stale local state. Delete it with `git branch -D release/v<version>`, then recreate from latest integration branch.
- PR exists and its body has `Tracking-Issue: #<release issue number>`: reuse that PR and branch.
- PR exists for a different release issue, or branch state is ambiguous: stop with `FAILED: release branch collision requires manual cleanup or --prefer ours|theirs`.
- `--prefer ours`: recreate the release branch from latest integration branch only after confirming no release tag `v<version>` exists.
- `--prefer theirs`: reuse the existing matching PR/branch only when version and tracking issue are clear.

Never run `git checkout -b release/v<version>` until the collision rules above have selected the create path.

## Branch rule
The version PR target is the integration branch from `RELEASE_FLOW`.

- Single-main repo: integration is `main`, so the version PR targets `main`.
- Dev-to-main repo: integration is `dev`, so the version PR targets `dev`.

## Does not own
- Merging the version PR.
- Tagging.
- Opening a production promotion PR.
