#!/usr/bin/env bash
set -euo pipefail

url="${KODY_ARG_URL:-}"
expected="${KODY_ARG_EXPECTED_STATUS:-200}"
goal_id="${KODY_ARG_GOAL:-}"
evidence="${KODY_ARG_EVIDENCE:-deploymentLive}"

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
print("KODY_DUTY_RESULT=" + json.dumps({
    "version": 1,
    "status": "pass" if evidence_value else "fail",
    "summary": f"{evidence} {'passed' if evidence_value else 'failed'}",
    "facts": facts,
}, separators=(",", ":")))
PY
}

if [[ -z "$url" ]]; then
  echo "KODY_REASON=verify deployment live: --url is required"
  echo "KODY_SKIP_AGENT=true"
  exit 64
fi

status="$(curl -L -sS -o /dev/null -w '%{http_code}' "$url" || true)"

if [[ "$status" == "$expected" ]]; then
  emit_goal_report "true" "deploymentUrl=${url}" "deploymentStatus=${status}"
  echo "KODY_REASON=deployment live at ${url} (${status})"
else
  emit_goal_report "false" "deploymentUrl=${url}" "deploymentStatus=${status}" "expectedStatus=${expected}"
  echo "KODY_REASON=deployment ${url} returned ${status}, expected ${expected}"
fi

echo "KODY_SKIP_AGENT=true"
