#!/usr/bin/env bash
set -euo pipefail

pr="${KODY_ARG_PR:-}"
goal_id="${KODY_ARG_GOAL:-}"
evidence="${KODY_ARG_EVIDENCE:-releasePrReady}"

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

print("KODY_CAPABILITY_REPORT=" + json.dumps({
    "target": {"type": "goal", "id": goal_id},
    "evidence": {evidence: evidence_value},
    "facts": facts,
}, separators=(",", ":")))
print("KODY_CAPABILITY_RESULT=" + json.dumps({
    "version": 1,
    "status": "pass" if evidence_value else "fail",
    "summary": f"{evidence} {'passed' if evidence_value else 'failed'}",
    "facts": facts,
}, separators=(",", ":")))
PY
}

if [[ ! "$pr" =~ ^[0-9]+$ ]]; then
  echo "KODY_REASON=verify release PR: --pr is required"
  echo "KODY_SKIP_AGENT=true"
  exit 64
fi

if ! pr_json="$(gh pr view "$pr" --json number,state,isDraft,url 2>/dev/null)"; then
  emit_goal_report "false" "releasePr=${pr}" "releasePrStatus=missing"
  echo "KODY_REASON=release PR #${pr} not found"
  echo "KODY_SKIP_AGENT=true"
  exit 0
fi

state="$(printf '%s' "$pr_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("state",""))')"
is_draft="$(printf '%s' "$pr_json" | python3 -c 'import json,sys; print(str(json.load(sys.stdin).get("isDraft", False)).lower())')"
url="$(printf '%s' "$pr_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("url",""))')"

if [[ "$state" != "OPEN" ]]; then
  emit_goal_report "false" "releasePr=${pr}" "releasePrUrl=${url}" "releasePrStatus=${state}"
  echo "KODY_REASON=release PR #${pr} is ${state}"
  echo "KODY_SKIP_AGENT=true"
  exit 0
fi

if [[ "$is_draft" == "true" ]]; then
  emit_goal_report "false" "releasePr=${pr}" "releasePrUrl=${url}" "releasePrStatus=draft"
  echo "KODY_REASON=release PR #${pr} is draft"
  echo "KODY_SKIP_AGENT=true"
  exit 0
fi

checks_status="green"
if checks="$(gh pr checks "$pr" --json state,name,bucket 2>/dev/null)"; then
  checks_status="$(CHECKS_JSON="$checks" python3 - <<'PY'
import json
import os

rows = json.loads(os.environ.get("CHECKS_JSON", "[]") or "[]")
states = [str(row.get("state") or row.get("bucket") or "").upper() for row in rows]
if any(state in ("FAILURE", "FAILED", "ERROR", "CANCELLED", "ACTION_REQUIRED") for state in states):
    print("failed")
elif any(state in ("PENDING", "QUEUED", "IN_PROGRESS", "WAITING") for state in states):
    print("pending")
else:
    print("green")
PY
)"
fi

if [[ "$checks_status" != "green" ]]; then
  emit_goal_report "false" "releasePr=${pr}" "releasePrUrl=${url}" "releasePrStatus=${checks_status}"
  echo "KODY_REASON=release PR #${pr} checks ${checks_status}"
  echo "KODY_SKIP_AGENT=true"
  exit 0
fi

emit_goal_report "true" "releasePr=${pr}" "releasePrUrl=${url}" "releasePrStatus=ready"
echo "KODY_REASON=release PR #${pr} is ready"
echo "KODY_SKIP_AGENT=true"
