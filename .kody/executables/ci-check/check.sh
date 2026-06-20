#!/usr/bin/env bash
#
# ci-check: check GitHub CI for one PR and report factual evidence.
#
# Inputs:
#   KODY_ARG_PR              PR number to check
#   KODY_ARG_GOAL            managed goal id to report to (optional)
#   KODY_ARG_EVIDENCE        evidence key to report (default: ciGreen)
#   KODY_ARG_TIMEOUT_SECONDS max seconds to wait for pending checks (default: 0)
#   KODY_ARG_POLL_SECONDS    seconds between polls (default: 30)

set -euo pipefail

pr="${KODY_ARG_PR:-}"
goal_id="${KODY_ARG_GOAL:-}"
evidence="${KODY_ARG_EVIDENCE:-ciGreen}"
timeout_seconds="${KODY_ARG_TIMEOUT_SECONDS:-0}"
poll_seconds="${KODY_ARG_POLL_SECONDS:-30}"

fail() {
  echo "KODY_REASON=$1"
  echo "KODY_SKIP_AGENT=true"
  exit "${2:-1}"
}

emit_goal_report() {
  local value="$1"
  shift
  [[ -z "$goal_id" ]] && return 0
  python3 - "$goal_id" "$evidence" "$value" "$@" <<'PY'
import json
import sys

goal_id = sys.argv[1]
evidence = sys.argv[2]
evidence_value = sys.argv[3] == "true"
facts = {}
for pair in sys.argv[4:]:
    key, value = pair.split("=", 1)
    if value == "":
        continue
    facts[key] = int(value) if value.isdigit() else value

print("KODY_DUTY_REPORT=" + json.dumps({
    "target": {"type": "goal", "id": goal_id},
    "evidence": {evidence: evidence_value},
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

[[ "$pr" =~ ^[0-9]+$ ]] || fail "ci-check: --pr is required" 99

deadline=$(( $(date +%s) + timeout_seconds ))

while true; do
  if ! raw=$(gh pr checks "$pr" --json name,state,bucket,workflow,link 2>&1); then
    fail "ci-check: gh pr checks failed for PR #${pr}: ${raw}" 1
  fi

  summary=$(summarize_checks "$raw")
  status=$(json_field "$summary" status)
  checks=$(json_field "$summary" checks)
  failed=$(json_field "$summary" failed)
  pending=$(json_field "$summary" pending)
  detail=$(json_field "$summary" detail)

  case "$status" in
    green)
      emit_goal_report "true" "pr=${pr}" "ciStatus=green" "ciChecks=${checks}"
      echo "KODY_REASON=CI green on PR #${pr} (${checks} checks)"
      echo "KODY_SKIP_AGENT=true"
      exit 0
      ;;
    failed)
      emit_goal_report "false" "pr=${pr}" "ciStatus=failed" "ciChecks=${checks}" "ciFailed=${failed}" "ciDetail=${detail}"
      echo "KODY_REASON=CI failed on PR #${pr}: ${detail}"
      echo "KODY_SKIP_AGENT=true"
      exit 0
      ;;
  esac

  if (( $(date +%s) >= deadline )); then
    emit_goal_report "false" "pr=${pr}" "ciStatus=pending" "ciChecks=${checks}" "ciPending=${pending}" "ciDetail=${detail}"
    echo "KODY_REASON=CI pending on PR #${pr}${detail:+: ${detail}}"
    echo "KODY_SKIP_AGENT=true"
    exit 0
  fi

  sleep "$poll_seconds"
done
