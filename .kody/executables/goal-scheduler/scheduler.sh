#!/usr/bin/env bash
#
# goal-scheduler: tick only consumer-activated managed goals.

set -euo pipefail

goals_dir=".kody/goals"

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
print(json.dumps([g for g in goals if isinstance(g, str) and g.strip()]))
PY
)

if [ "$active_goals_json" = "[]" ]; then
  echo "[goal-scheduler] no company.activeGoals configured — store goals inactive"
  echo "KODY_SKIP_AGENT=true"
  exit 0
fi

git fetch origin kody-state --quiet 2>/dev/null || true
git checkout origin/kody-state -- "$goals_dir" 2>/dev/null || true

if [ ! -d "$goals_dir" ]; then
  echo "[goal-scheduler] no $goals_dir — nothing schedule"
  echo "KODY_SKIP_AGENT=true"
  exit 0
fi

shopt -s nullglob
state_files=("$goals_dir"/*/state.json)
shopt -u nullglob

if [ "${#state_files[@]}" -eq 0 ]; then
  echo "[goal-scheduler] no goal state files yet"
  echo "KODY_SKIP_AGENT=true"
  exit 0
fi

active=0
managed_active=0

for state_file in "${state_files[@]}"; do
  [ -f "$state_file" ] || continue

  goal_id=$(basename "$(dirname "$state_file")")
  activated=$(python3 -c 'import json,sys; print("yes" if sys.argv[1] in json.loads(sys.argv[2]) else "no")' "$goal_id" "$active_goals_json")
  if [ "$activated" != "yes" ]; then
    continue
  fi

  state=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("state", ""))' "$state_file" 2>/dev/null || echo "")
  if [ "$state" != "active" ]; then
    continue
  fi

  active=$((active + 1))
  managed=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print("yes" if all(k in d for k in ("type","destination","duties","route","facts","blockers")) else "no")' "$state_file" 2>/dev/null || echo "no")
  if [ "$managed" != "yes" ]; then
    echo "[goal-scheduler] skip $goal_id: legacy goal files are not managed-goal activations"
    continue
  fi

  managed_active=$((managed_active + 1))
  echo "[goal-scheduler] -> tick $goal_id (goal-manager)"
  if ! kody-engine goal-manager --goal "$goal_id"; then
    echo "[goal-scheduler] tick $goal_id failed (continuing)"
  fi
done

echo "[goal-scheduler] scanned ${#state_files[@]} goal(s), active=${active}, managed=${managed_active}"
echo "KODY_SKIP_AGENT=true"
