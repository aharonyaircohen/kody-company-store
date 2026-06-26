set -euo pipefail

dry_run="${KODY_ARG_DRY_RUN:-false}"
goal_id="${KODY_ARG_GOAL:-}"
default_branch="${KODY_CFG_GIT_DEFAULTBRANCH:-main}"
release_branch="${KODY_CFG_RELEASE_RELEASEBRANCH:-}"

emit_goal_report() {
  local evidence="$1"
  shift
  [[ -z "$goal_id" ]] && return 0
  python3 - "$goal_id" "$evidence" "$@" <<'PY'
import json
import sys

goal_id = sys.argv[1]
evidence = sys.argv[2]
facts = {}
for pair in sys.argv[3:]:
    key, value = pair.split("=", 1)
    if value == "":
        continue
    facts[key] = int(value) if value.isdigit() else value

print("KODY_CAPABILITY_REPORT=" + json.dumps({
    "target": {"type": "goal", "id": goal_id},
    "evidence": {evidence: True},
    "facts": facts,
}, separators=(",", ":")))
print("KODY_CAPABILITY_RESULT=" + json.dumps({
    "version": 1,
    "status": "pass",
    "summary": f"{evidence} reported",
    "facts": facts,
}, separators=(",", ":")))
PY
}

read_version() {
  local branch="$1"
  if git fetch origin "$branch" --quiet 2>/dev/null; then
    if pkg=$(git show "origin/${branch}:package.json" 2>/dev/null); then
      echo "$pkg" | python3 -c "import json,sys; print(json.load(sys.stdin)['version'])" 2>/dev/null && return
    fi
  fi
  python3 -c "import json; print(json.load(open('package.json'))['version'])" 2>/dev/null || echo "unknown"
}

read_changelog_section() {
  local branch="$1" ver="$2" raw=""
  if ! raw=$(git show "origin/${branch}:CHANGELOG.md" 2>/dev/null); then
    return 0
  fi
  printf '%s' "$raw" | awk -v ver="$ver" '
    BEGIN { capture = 0 }
    /^##[[:space:]]/ {
      if (capture) { exit }
      header = $0
      sub(/^##[[:space:]]+/, "", header)
      sub(/^\[/, "", header); sub(/\].*/, "", header)
      sub(/[[:space:]].*/, "", header)
      sub(/[(].*/, "", header)
      sub(/^v/, "", header)
      if (header == ver) { capture = 1; next }
    }
    capture { print }
  ' | awk '
    NF { if (!started) started = 1; out[++n] = $0; last = n; next }
    started { out[++n] = $0 }
    END { for (i = 1; i <= last; i++) print out[i] }
  '
}

build_pr_body() {
  local tracking_line="$1"
  printf 'Automated release promotion PR opened by kody - promotes `%s` to `%s` for release **v%s**.\n\n' \
    "$default_branch" "$release_branch" "$version"
  if [[ -n "$changelog_section" ]]; then
    printf '<!-- kody-changelog-start -->\n## What'\''s changing in v%s\n\n%s\n<!-- kody-changelog-end -->\n\n' \
      "$version" "$changelog_section"
  fi
  printf 'Merge this PR to promote v%s to `%s`.%s\n' \
    "$version" "$release_branch" "$tracking_line"
}

if [[ -z "$release_branch" || "$release_branch" == "$default_branch" ]]; then
  echo "KODY_REASON=no releaseBranch configured (or equals defaultBranch) - nothing to promote"
  echo "KODY_SKIP_AGENT=true"
  exit 0
fi

version=$(read_version "$default_branch")
echo "release promote: v${version}"

if [[ "$dry_run" == "true" ]]; then
  echo "KODY_REASON=dry-run - would open PR ${default_branch} -> ${release_branch}"
  echo "KODY_SKIP_AGENT=true"
  exit 0
fi

export HUSKY=0 SKIP_HOOKS=1 CI="${CI:-1}"

existing=$(gh pr list --head "$default_branch" --base "$release_branch" --state open --json url --limit 1 2>/dev/null \
  | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data[0]["url"] if data else "")' 2>/dev/null \
  || echo "")

issue_arg="${KODY_ARG_ISSUE:-}"
tracking_line=""
if [[ "$issue_arg" =~ ^[0-9]+$ && "$issue_arg" != "0" ]]; then
  tracking_line=$'\n\nTracking-Issue: #'"${issue_arg}"
fi

changelog_section=$(read_changelog_section "$default_branch" "$version" || true)
if [[ -z "$changelog_section" ]]; then
  echo "  no CHANGELOG section for v${version} on origin/${default_branch} - using minimal PR body"
fi
body=$(build_pr_body "$tracking_line")

body_max=65000
if (( ${#body} > body_max )); then
  echo "[kody release-promote] PR body ${#body} chars > ${body_max} - truncating changelog" >&2
  budget=$(( body_max - 2000 ))
  changelog_section="${changelog_section:0:budget}"$'\n\n_...changelog truncated; see CHANGELOG.md on the branch._'
  body=$(build_pr_body "$tracking_line")
  (( ${#body} > body_max )) && body="${body:0:body_max}"
fi

if [[ -n "$existing" ]]; then
  echo "  reusing existing promotion PR: ${existing}"
  pr_url="$existing"
  if ! printf '%s' "$body" | gh pr edit "$pr_url" --body-file - >/dev/null 2>&1; then
    echo "[kody release-promote] WARN: failed to refresh promotion PR body" >&2
  fi
else
  if ! pr_url=$(printf '%s' "$body" | gh pr create --head "$default_branch" --base "$release_branch" --title "promote: ${default_branch} -> ${release_branch} (v${version})" --body-file -); then
    echo "KODY_REASON=release promote: gh pr create failed"
    echo "KODY_SKIP_AGENT=true"
    exit 1
  fi
fi

if [[ -z "$pr_url" ]]; then
  echo "KODY_REASON=release promote: empty PR URL after gh pr create"
  echo "KODY_SKIP_AGENT=true"
  exit 1
fi

if [[ "${issue_arg:-}" =~ ^[0-9]+$ && "${issue_arg:-0}" != "0" ]]; then
  pr_number="${pr_url##*/}"
  if [[ "$pr_number" =~ ^[0-9]+$ ]]; then
    cur_body=$(gh issue view "$issue_arg" --json body -q .body 2>/dev/null || echo "")
    cleaned_body=$(printf '%s' "$cur_body" | sed -E '/<!-- kody-release-promotion-pr:[^>]*-->/d')
    {
      printf '%s' "$cleaned_body"
      printf '\n\n<!-- kody-release-promotion-pr: #%s -->\n' "$pr_number"
    } | gh issue edit "$issue_arg" --body-file - >/dev/null 2>&1 || \
      echo "[kody release-promote] WARN: failed to write kody-release-promotion-pr marker to issue #${issue_arg}"
  fi
fi

echo "RELEASE_PROMOTION_PR=${pr_url}"
emit_goal_report "releasePromotionPrExists" "version=${version}" "promotionPrUrl=${pr_url}" "promotionPr=${pr_url##*/}"
echo "KODY_PR_URL=${pr_url}"
echo "KODY_REASON=opened promotion PR ${default_branch} -> ${release_branch}"
echo "KODY_SKIP_AGENT=true"
