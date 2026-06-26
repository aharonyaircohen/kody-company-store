#!/usr/bin/env bash
#
# release-merge: wait for a release PR to pass checks, squash-merge it, and
# report mainMerged to a managed goal.
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

failed = []
pending = []
for row in rows:
    if not isinstance(row, dict):
        continue
    bucket = str(row.get("bucket") or "").lower()
    state = str(row.get("state") or "").lower()
    label = row.get("workflow") or row.get("name") or "check"
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

[[ "$pr" =~ ^[0-9]+$ ]] || fail "release-merge: --pr is required" 99

state="$(gh pr view "$pr" --json state --jq '.state' 2>/dev/null || true)"
if [[ "$state" == "MERGED" ]]; then
  merge_sha="$(gh pr view "$pr" --json mergeCommit --jq '.mergeCommit.oid // ""' 2>/dev/null || true)"
  emit_goal_report "mainMerged" "releasePr=${pr}" "mergeCommit=${merge_sha}"
  echo "KODY_SKIP_AGENT=true"
  cat <<RESULT
DONE
PR_SUMMARY:
- Release PR #${pr} was already merged.
RESULT
  exit 0
fi

[[ "$state" == "OPEN" ]] || fail "release-merge: PR #${pr} is not open (state: ${state:-unknown})" 1

deadline=$(( $(date +%s) + timeout_seconds ))
while true; do
  if ! raw="$(gh pr checks "$pr" --json name,state,bucket,workflow,link 2>&1)"; then
    fail "release-merge: gh pr checks failed for PR #${pr}: ${raw}" 1
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

gh pr merge "$pr" --squash --delete-branch
merge_sha="$(gh pr view "$pr" --json mergeCommit --jq '.mergeCommit.oid // ""')"

if [[ "$issue" =~ ^[0-9]+$ ]]; then
  gh issue comment "$issue" --body "Merged release PR #${pr}${merge_sha:+ at ${merge_sha}}." >/dev/null || true
fi

emit_goal_report "mainMerged" "releasePr=${pr}" "mergeCommit=${merge_sha}"
echo "KODY_SKIP_AGENT=true"
cat <<RESULT
DONE
PR_SUMMARY:
- Merged release PR #${pr}${merge_sha:+ at ${merge_sha}}.
RESULT
