#!/usr/bin/env bash
#
# goal-scheduler: tick only consumer-activated managed goal instances.

set -euo pipefail

instances_dir=".kody/goals/instances"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[goal-scheduler] FATAL: python3 not found on PATH" >&2
  exit 1
fi

active_goals_json=$(python3 - <<'PY'
import json
from pathlib import Path

path = Path("kody.config.json")
if not path.exists():
    print("[]")
    raise SystemExit

try:
    config = json.loads(path.read_text())
except Exception:
    print("[]")
    raise SystemExit

goals = config.get("company", {}).get("activeGoals", [])
if not isinstance(goals, list):
    goals = []
print(json.dumps([g.strip() for g in goals if isinstance(g, str) and g.strip()]))
PY
)

if [ "$active_goals_json" = "[]" ]; then
  echo "[goal-scheduler] no company.activeGoals configured — store goals inactive"
  echo "KODY_SKIP_AGENT=true"
  exit 0
fi

git fetch origin kody-state --quiet 2>/dev/null || true
git checkout origin/kody-state -- "$instances_dir" 2>/dev/null || true

if [ ! -d "$instances_dir" ]; then
  echo "[goal-scheduler] no $instances_dir — nothing schedule"
  echo "KODY_SKIP_AGENT=true"
  exit 0
fi

shopt -s nullglob
state_files=("$instances_dir"/*/state.json)
shopt -u nullglob

if [ "${#state_files[@]}" -eq 0 ]; then
  echo "[goal-scheduler] no goal instances yet"
  echo "KODY_SKIP_AGENT=true"
  exit 0
fi

active=0
managed_active=0

for state_file in "${state_files[@]}"; do
  [ -f "$state_file" ] || continue

  goal_id=$(basename "$(dirname "$state_file")")
  read -r state activated managed < <(python3 - "$state_file" "$goal_id" "$active_goals_json" <<'PY'
import json
import sys

state_file, goal_id, active_json = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = json.load(open(state_file))
except Exception:
    print("invalid no no")
    raise SystemExit

active = set(json.loads(active_json))
template = data.get("template") or data.get("sourceTemplate") or data.get("templateId")
activated = goal_id in active or (isinstance(template, str) and template in active)
managed = all(k in data for k in ("type", "destination", "duties", "route", "facts", "blockers"))
print(data.get("state", ""), "yes" if activated else "no", "yes" if managed else "no")
PY
  )

  if [ "$activated" != "yes" ] || [ "$state" != "active" ]; then
    continue
  fi

  active=$((active + 1))
  if [ "$managed" != "yes" ]; then
    echo "[goal-scheduler] skip $goal_id: legacy goal files are not managed-goal instances"
    continue
  fi

  managed_active=$((managed_active + 1))
  echo "[goal-scheduler] -> tick $goal_id (goal-manager)"
  if ! kody-engine goal-manager --goal "$goal_id"; then
    echo "[goal-scheduler] tick $goal_id failed (continuing)"
  fi
done

echo "[goal-scheduler] scanned ${#state_files[@]} goal instance(s), active=${active}, managed=${managed_active}"
echo "KODY_SKIP_AGENT=true"
