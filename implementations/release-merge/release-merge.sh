#!/usr/bin/env bash
#
# release-merge: wait for a release PR to pass checks, squash-merge it, and
# report branch-specific merge evidence to a managed goal.
#
# Inputs:
#   KODY_ARG_PR              release PR number to merge
#   KODY_ARG_ISSUE           issue number to comment on (optional)
#   KODY_ARG_GOAL            managed goal id to report to (optional)
#   KODY_ARG_TIMEOUT_SECONDS max seconds to wait for pending checks (default 1800)
#   KODY_ARG_POLL_SECONDS    seconds between polls (default 30)

set -euo pipefail

pr="${KODY_ARG_PR:-}"
issue="${KODY_ARG_ISSUE:-}"
goal_id="${KODY_ARG_GOAL:-}"
timeout_seconds="${KODY_ARG_TIMEOUT_SECONDS:-1800}"
poll_seconds="${KODY_ARG_POLL_SECONDS:-30}"
default_branch="${KODY_CFG_GIT_DEFAULTBRANCH:-main}"
release_branch="${KODY_CFG_RELEASE_RELEASEBRANCH:-}"

fail() {
  echo "KODY_REASON=$1"
  echo "KODY_SKIP_AGENT=true"
  exit "${2:-1}"
}

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

summarize_checks() {
  RAW_CHECKS="$1" python3 - <<'PY'
import json
import os

rows = json.loads(os.environ.get("RAW_CHECKS", "[]") or "[]")
if not isinstance(rows, list):
    rows = []

ignored_workflows = {"Deploy Wiki to GitHub Pages", "Publish Complete"}
ignored_names = {"deploy", "close-publish-issue"}
failed = []
pending = []
for row in rows:
    if not isinstance(row, dict):
        continue
    workflow = str(row.get("workflow") or "")
    name = str(row.get("name") or "")
    if workflow in ignored_workflows or name in ignored_names:
        continue
    bucket = str(row.get("bucket") or "").lower()
    state = str(row.get("state") or "").lower()
    label = workflow or name or "check"
    if bucket in {"fail", "cancel"} or state in {"failure", "failed", "error", "cancelled", "timed_out"}:
        failed.append(str(label))
    elif bucket == "pending" or state in {"pending", "queued", "in_progress", "waiting", "requested"}:
        pending.append(str(label))

status = "green"
if failed:
    status = "failed"
elif pending or not rows:
    status = "pending"

print(json.dumps({
    "status": status,
    "checks": len(rows),
    "failed": len(failed),
    "pending": len(pending) if rows else 1,
    "detail": "; ".join((failed or pending)[:5]),
}, separators=(",", ":")))
PY
}

json_field() {
  SUMMARY_JSON="$1" FIELD="$2" python3 - <<'PY'
import json
import os

data = json.loads(os.environ["SUMMARY_JSON"])
print(data.get(os.environ["FIELD"], ""))
PY
}

merge_evidence_for_base() {
  local base="$1"
  if [[ -n "$release_branch" && "$release_branch" != "$default_branch" && "$base" == "$release_branch" ]]; then
    echo "releaseBranchMerged"
    return
  fi
  if [[ "$base" == "$default_branch" ]]; then
    echo "defaultBranchMerged"
    return
  fi
  fail "release-merge: PR #${pr} targets '${base}', expected '${default_branch}'${release_branch:+ or '${release_branch}'}" 1
}

[[ "$pr" =~ ^[0-9]+$ ]] || fail "release-merge: --pr is required" 99

pr_view="$(gh pr view "$pr" --json state,baseRefName,headRefName,mergeCommit 2>/dev/null || true)"
state="$(printf '%s' "$pr_view" | python3 -c 'import json,sys; print((json.load(sys.stdin) or {}).get("state",""))' 2>/dev/null || true)"
base_ref="$(printf '%s' "$pr_view" | python3 -c 'import json,sys; print((json.load(sys.stdin) or {}).get("baseRefName",""))' 2>/dev/null || true)"
head_ref="$(printf '%s' "$pr_view" | python3 -c 'import json,sys; print((json.load(sys.stdin) or {}).get("headRefName",""))' 2>/dev/null || true)"
evidence="$(merge_evidence_for_base "$base_ref")"

if [[ "$state" == "MERGED" ]]; then
  merge_sha="$(printf '%s' "$pr_view" | python3 -c 'import json,sys; print(((json.load(sys.stdin) or {}).get("mergeCommit") or {}).get("oid",""))' 2>/dev/null || true)"
  emit_goal_report "$evidence" "mergedPr=${pr}" "mergeCommit=${merge_sha}" "mergedBaseBranch=${base_ref}"
  echo "KODY_SKIP_AGENT=true"
  cat <<RESULT
DONE
PR_SUMMARY:
- Release PR #${pr} was already merged into ${base_ref}.
RESULT
  exit 0
fi

[[ "$state" == "OPEN" ]] || fail "release-merge: PR #${pr} is not open (state: ${state:-unknown})" 1

deadline=$(( $(date +%s) + timeout_seconds ))
while true; do
  if ! raw="$(gh pr checks "$pr" --json name,state,bucket,workflow,link 2>&1)"; then
    if printf '%s' "$raw" | grep -qi 'no checks reported'; then
      raw="[]"
    else
      fail "release-merge: gh pr checks failed for PR #${pr}: ${raw}" 1
    fi
  fi

  summary="$(summarize_checks "$raw")"
  status="$(json_field "$summary" status)"
  checks="$(json_field "$summary" checks)"
  failed="$(json_field "$summary" failed)"
  pending="$(json_field "$summary" pending)"
  detail="$(json_field "$summary" detail)"

  if [[ "$status" == "green" ]]; then
    break
  fi

  if [[ "$status" == "failed" ]]; then
    fail "release-merge: PR #${pr} checks failed (${detail:-${failed} failed})" 1
  fi

  now="$(date +%s)"
  if (( now >= deadline )); then
    fail "release-merge: PR #${pr} checks still pending after ${timeout_seconds}s (${detail:-${pending} pending})" 1
  fi

  echo "release-merge: PR #${pr} checks pending (${pending}/${checks}); sleeping ${poll_seconds}s"
  sleep "$poll_seconds"
done

merge_args=(--squash)
if [[ -n "$release_branch" && "$head_ref" == "$default_branch" && "$base_ref" == "$release_branch" ]]; then
  merge_args=(--merge)
fi
if [[ "$head_ref" != "$default_branch" && ( -z "$release_branch" || "$head_ref" != "$release_branch" ) ]]; then
  merge_args+=(--delete-branch)
fi

if ! merge_output="$(gh pr merge "$pr" "${merge_args[@]}" 2>&1)"; then
  if printf '%s' "$merge_output" | grep -qiE 'base branch policy|add the `--auto` flag|--auto'; then
    printf '%s\n' "$merge_output"
    gh pr merge "$pr" "${merge_args[@]}" --auto
  else
    fail "release-merge: gh pr merge failed for PR #${pr}: ${merge_output}" 1
  fi
fi

while true; do
  pr_view="$(gh pr view "$pr" --json state,mergeCommit 2>/dev/null || true)"
  state="$(printf '%s' "$pr_view" | python3 -c 'import json,sys; print((json.load(sys.stdin) or {}).get("state",""))' 2>/dev/null || true)"
  if [[ "$state" == "MERGED" ]]; then
    break
  fi
  now="$(date +%s)"
  if (( now >= deadline )); then
    fail "release-merge: PR #${pr} auto-merge did not complete after ${timeout_seconds}s (state: ${state:-unknown})" 1
  fi
  echo "release-merge: PR #${pr} waiting for GitHub auto-merge; sleeping ${poll_seconds}s"
  sleep "$poll_seconds"
done

merge_sha="$(printf '%s' "$pr_view" | python3 -c 'import json,sys; print(((json.load(sys.stdin) or {}).get("mergeCommit") or {}).get("oid",""))' 2>/dev/null || true)"

if [[ "$issue" =~ ^[0-9]+$ ]]; then
  gh issue comment "$issue" --body "Merged release PR #${pr} into ${base_ref}${merge_sha:+ at ${merge_sha}}." >/dev/null || true
fi

emit_goal_report "$evidence" "mergedPr=${pr}" "mergeCommit=${merge_sha}" "mergedBaseBranch=${base_ref}"
echo "KODY_SKIP_AGENT=true"
cat <<RESULT
DONE
PR_SUMMARY:
- Merged release PR #${pr} into ${base_ref}${merge_sha:+ at ${merge_sha}}.
RESULT
