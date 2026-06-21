#!/usr/bin/env bash
set -euo pipefail

package_name="${KODY_ARG_PACKAGE:-}"
version="${KODY_ARG_VERSION:-}"
goal_id="${KODY_ARG_GOAL:-}"
evidence="${KODY_ARG_EVIDENCE:-packagePublished}"

read_package_field() {
  local field="$1"
  python3 - "$field" <<'PY'
import json
import sys

field = sys.argv[1]
try:
    with open("package.json", "r", encoding="utf-8") as fh:
        data = json.load(fh)
    print(data.get(field, ""))
except Exception:
    print("")
PY
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
    facts[key] = value

print("KODY_DUTY_REPORT=" + json.dumps({
    "target": {"type": "goal", "id": goal_id},
    "evidence": {evidence: evidence_value},
    "facts": facts,
}, separators=(",", ":")))
PY
}

[[ -z "$package_name" ]] && package_name="$(read_package_field name)"
[[ -z "$version" ]] && version="$(read_package_field version)"

if [[ -z "$package_name" || -z "$version" ]]; then
  echo "KODY_REASON=verify package published: package and version are required"
  echo "KODY_SKIP_AGENT=true"
  exit 64
fi

if published="$(npm view "${package_name}@${version}" version 2>/dev/null)" && [[ "$published" == "$version" ]]; then
  emit_goal_report "true" "package=${package_name}" "version=${version}" "publishStatus=published"
  echo "KODY_REASON=${package_name}@${version} is published"
else
  emit_goal_report "false" "package=${package_name}" "version=${version}" "publishStatus=missing"
  echo "KODY_REASON=${package_name}@${version} is not published"
fi

echo "KODY_SKIP_AGENT=true"
