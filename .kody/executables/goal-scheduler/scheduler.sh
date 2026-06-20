#!/usr/bin/env bash
#
# goal-scheduler: instantiate scheduled goal templates, then tick activated
# managed goal instances.

set -euo pipefail

instances_dir=".kody/goals/instances"
local_templates_dir=".kody/goals/templates"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
store_templates_dir="$(cd "$script_dir/../.." && pwd)/goals/templates"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[goal-scheduler] FATAL: python3 not found on PATH" >&2
  exit 1
fi

goal_config_json=$(python3 - <<'PY'
import json
import re
from pathlib import Path

SLUG = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")

path = Path("kody.config.json")
if not path.exists():
    print(json.dumps({"active": [], "schedules": [], "owner": None, "repo": None}))
    raise SystemExit

try:
    config = json.loads(path.read_text())
except Exception:
    print(json.dumps({"active": [], "schedules": [], "owner": None, "repo": None}))
    raise SystemExit

company = config.get("company") if isinstance(config.get("company"), dict) else {}
goals = company.get("activeGoals", [])
if not isinstance(goals, list):
    goals = []

active = []
schedules = []
for item in goals:
    if isinstance(item, str):
        slug = item.strip()
        if slug:
            active.append(slug)
        continue

    if not isinstance(item, dict):
        continue

    template = item.get("template")
    every = item.get("every")
    if not isinstance(template, str) or not template.strip():
        continue
    template = template.strip()
    if not SLUG.match(template):
        continue

    entry = {"template": template}
    if isinstance(every, str) and every.strip():
        entry["every"] = every.strip()
    if isinstance(item.get("idPrefix"), str) and item["idPrefix"].strip():
        prefix = item["idPrefix"].strip()
        if SLUG.match(prefix):
            entry["idPrefix"] = prefix
    if isinstance(item.get("facts"), dict):
        entry["facts"] = item["facts"]
    schedules.append(entry)

github = config.get("github") if isinstance(config.get("github"), dict) else {}
payload = {
    "active": sorted(set(active)),
    "schedules": schedules,
    "owner": github.get("owner") if isinstance(github.get("owner"), str) else None,
    "repo": github.get("repo") if isinstance(github.get("repo"), str) else None,
}
print(json.dumps(payload))
PY
)

read -r active_count schedule_count < <(python3 - "$goal_config_json" <<'PY'
import json
import sys

config = json.loads(sys.argv[1])
print(len(config["active"]), len(config["schedules"]))
PY
)

if [ "$active_count" -eq 0 ] && [ "$schedule_count" -eq 0 ]; then
  echo "[goal-scheduler] no company.activeGoals configured - store goals inactive"
  echo "KODY_SKIP_AGENT=true"
  exit 0
fi

git fetch origin kody-state --quiet 2>/dev/null || true
git checkout origin/kody-state -- "$instances_dir" 2>/dev/null || true

activation_json=$(python3 - "$goal_config_json" "$instances_dir" "$local_templates_dir" "$store_templates_dir" <<'PY'
import base64
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

config = json.loads(sys.argv[1])
instances_dir = Path(sys.argv[2])
template_roots = [Path(sys.argv[3]), Path(sys.argv[4])]

INTERVAL = re.compile(r"^([1-9][0-9]*)([mhdw])$")
STATE_BRANCH = "kody-state"


def now_utc() -> datetime:
    raw = os.environ.get("KODY_GOAL_SCHEDULER_NOW", "").strip()
    if raw:
        if raw.endswith("Z"):
            raw = raw[:-1] + "+00:00"
        return datetime.fromisoformat(raw).astimezone(timezone.utc)
    return datetime.now(timezone.utc)


def interval_seconds(every: str) -> int:
    match = INTERVAL.match(every)
    if not match:
        raise ValueError(f"unsupported schedule '{every}'")
    amount = int(match.group(1))
    unit = match.group(2)
    return amount * {"m": 60, "h": 3600, "d": 86400, "w": 604800}[unit]


def bucket_suffix(every: str, now: datetime) -> str:
    match = INTERVAL.match(every)
    if not match:
        raise ValueError(f"unsupported schedule '{every}'")
    amount = int(match.group(1))
    unit = match.group(2)
    if amount == 1 and unit == "d":
        return now.strftime("%Y-%m-%d")
    if amount == 1 and unit == "w":
        year, week, _ = now.isocalendar()
        return f"{year}-W{week:02d}"
    if amount == 1 and unit == "h":
        return now.strftime("%Y-%m-%dT%H")
    return f"b{int(now.timestamp()) // interval_seconds(every)}"


def find_template(template: str) -> Path | None:
    for root in template_roots:
        candidate = root / template / "state.json"
        if candidate.exists():
            return candidate
    return None


def gh(args: list[str], input_text: str | None = None) -> str:
    result = subprocess.run(
        ["gh", *args],
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or f"gh exited {result.returncode}")
    return result.stdout


def is_not_found(err: Exception) -> bool:
    msg = str(err)
    return "HTTP 404" in msg or "Not Found" in msg


def ensure_state_branch(owner: str, repo: str) -> None:
    try:
        gh(["api", f"/repos/{owner}/{repo}/git/ref/heads/{STATE_BRANCH}"])
        return
    except Exception as err:
        if not is_not_found(err):
            raise

    repo_info = json.loads(gh(["api", f"/repos/{owner}/{repo}"]))
    default_branch = repo_info.get("default_branch")
    if not isinstance(default_branch, str) or not default_branch:
        raise RuntimeError("could not resolve default branch")
    base_ref = json.loads(gh(["api", f"/repos/{owner}/{repo}/git/ref/heads/{default_branch}"]))
    sha = base_ref.get("object", {}).get("sha")
    if not isinstance(sha, str) or not sha:
        raise RuntimeError(f"could not resolve {default_branch} sha")
    try:
        gh(
            ["api", "--method", "POST", f"/repos/{owner}/{repo}/git/refs", "--input", "-"],
            json.dumps({"ref": f"refs/heads/{STATE_BRANCH}", "sha": sha}),
        )
    except Exception as err:
        if "already exists" not in str(err) and "HTTP 422" not in str(err):
            raise


def remote_goal_exists(owner: str, repo: str, goal_id: str) -> bool:
    path = f".kody/goals/instances/{goal_id}/state.json"
    try:
        gh(["api", f"/repos/{owner}/{repo}/contents/{path}?ref={STATE_BRANCH}"])
        return True
    except Exception as err:
        if is_not_found(err):
            return False
        raise


def persist_goal(owner: str, repo: str, goal_id: str, state_text: str) -> None:
    if os.environ.get("KODY_GOAL_SCHEDULER_SKIP_PERSIST") == "1":
        return
    if not owner or not repo:
        raise RuntimeError("missing github.owner/github.repo in kody.config.json")
    if not shutil_which("gh"):
        raise RuntimeError("gh is required to persist scheduled goal instances")

    ensure_state_branch(owner, repo)
    if remote_goal_exists(owner, repo, goal_id):
        return
    path = f".kody/goals/instances/{goal_id}/state.json"
    payload = {
        "message": f"chore(goals): create {goal_id}",
        "content": base64.b64encode(state_text.encode("utf-8")).decode("ascii"),
        "branch": STATE_BRANCH,
    }
    try:
        gh(["api", "--method", "PUT", f"/repos/{owner}/{repo}/contents/{path}", "--input", "-"], json.dumps(payload))
    except Exception as err:
        if "HTTP 409" in str(err) or "HTTP 422" in str(err):
            return
        raise


def shutil_which(name: str) -> str | None:
    for folder in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(folder) / name
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


active = set(config["active"])
created = []
errors = []
now = now_utc()
owner = config.get("owner")
repo = config.get("repo")

for schedule in config["schedules"]:
    every = schedule.get("every")
    if not every:
        active.add(schedule["template"])
        continue
    try:
        suffix = bucket_suffix(every, now)
        prefix = schedule.get("idPrefix") or schedule["template"]
        goal_id = f"{prefix}-{suffix}"
        active.add(goal_id)
        state_path = instances_dir / goal_id / "state.json"
        if state_path.exists():
            continue

        template_path = find_template(schedule["template"])
        if template_path is None:
            errors.append(f"template {schedule['template']} not found")
            continue

        data = json.loads(template_path.read_text())
        facts = data.get("facts") if isinstance(data.get("facts"), dict) else {}
        facts.update(schedule.get("facts") or {})
        data["kind"] = "instance"
        data["template"] = schedule["template"]
        data["sourceTemplate"] = schedule["template"]
        data["state"] = "active"
        data["facts"] = facts
        data.setdefault("createdAt", now.isoformat().replace("+00:00", "Z"))
        data["updatedAt"] = now.isoformat().replace("+00:00", "Z")
        state_text = json.dumps(data, indent=2, sort_keys=True) + "\n"
        state_path.parent.mkdir(parents=True, exist_ok=True)
        state_path.write_text(state_text)
        persist_goal(owner, repo, goal_id, state_text)
        created.append(goal_id)
    except Exception as err:
        errors.append(f"{schedule.get('template', '<unknown>')}: {err}")

print(json.dumps({"active": sorted(active), "created": created, "errors": errors}))
PY
)

python3 - "$activation_json" <<'PY'
import json
import sys

result = json.loads(sys.argv[1])
for goal_id in result.get("created", []):
    print(f"[goal-scheduler] created scheduled instance {goal_id}")
for error in result.get("errors", []):
    print(f"[goal-scheduler] schedule skipped: {error}")
PY

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
  read -r state activated managed < <(python3 - "$state_file" "$goal_id" "$activation_json" <<'PY'
import json
import sys

state_file, goal_id, activation_json = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = json.load(open(state_file))
except Exception:
    print("invalid no no")
    raise SystemExit

active = set(json.loads(activation_json).get("active", []))
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
