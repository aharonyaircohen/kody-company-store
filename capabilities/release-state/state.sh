#!/usr/bin/env bash
# Observe release state without changing repository or registry state.
set -euo pipefail

goal_id="${KODY_ARG_GOAL:-}"
evidence="${KODY_ARG_EVIDENCE:-releaseStateObserved}"
package_name="${KODY_ARG_PACKAGE:-}"
default_branch="${KODY_CFG_GIT_DEFAULTBRANCH:-main}"

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))'
}

emit_goal_report() {
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
    if value.isdigit():
        facts[key] = int(value)
    elif value in ("true", "false"):
        facts[key] = value == "true"
    else:
        facts[key] = value

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

version="$(read_package_field version)"
[[ -z "$package_name" ]] && package_name="$(read_package_field name)"
tag=""
[[ -n "$version" ]] && tag="v${version}"

release_pr=""
if gh pr list --state open --search "release" --json number,url --limit 20 >/tmp/kody-release-prs.json 2>/dev/null; then
  release_pr="$(python3 - <<'PY'
import json

try:
    rows = json.load(open("/tmp/kody-release-prs.json", "r", encoding="utf-8"))
except Exception:
    rows = []

for row in rows:
    number = row.get("number")
    if number:
        print(number)
        break
PY
)"
fi

tag_exists="false"
if [[ -n "$tag" ]] && git rev-parse --verify "$tag" >/dev/null 2>&1; then
  tag_exists="true"
elif [[ -n "$tag" ]] && git ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
  tag_exists="true"
fi

package_published="false"
if [[ -n "$package_name" && -n "$version" ]] && npm view "${package_name}@${version}" version >/dev/null 2>&1; then
  package_published="true"
fi

emit_goal_report \
  "version=${version}" \
  "package=${package_name}" \
  "releaseTag=${tag}" \
  "releaseTagExists=${tag_exists}" \
  "releasePr=${release_pr}" \
  "packagePublished=${package_published}" \
  "defaultBranch=${default_branch}"

echo "KODY_REASON=observed release state for ${package_name:-package} ${version:-unknown}"
echo "KODY_SKIP_AGENT=true"
