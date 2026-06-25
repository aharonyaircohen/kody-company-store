#!/usr/bin/env bash
#
# goal-scheduler: instantiate scheduled goal templates and tick active managed
# goal instances from the configured Kody state repo.
set -euo pipefail

local_templates_dir=".kody/goals/templates"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
store_templates_dir="$(cd "$script_dir/../.." && pwd)/goals/templates"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[goal-scheduler] FATAL: python3 not found on PATH" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "[goal-scheduler] FATAL: gh not found on PATH" >&2
  exit 1
fi

python3 - "$local_templates_dir" "$store_templates_dir" <<'PY'
import base64
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

local_templates_dir = Path(sys.argv[1])
store_templates_dir = Path(sys.argv[2])
template_roots = [local_templates_dir, store_templates_dir]
instances_dir = Path(".kody/goals/instances")
LOCAL_MODE = os.environ.get("KODY_GOAL_SCHEDULER_SKIP_PERSIST") == "1"

SLUG = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
INTERVAL = re.compile(r"^(\d+)([mhdw])$")
MANAGED_KEYS = ("type", "destination", "agentResponsibilities", "route", "facts", "blockers")


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


def load_config() -> dict:
    path = Path("kody.config.json")
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def active_goal_config(config: dict) -> tuple[set[str], list[dict]]:
    company = config.get("company") if isinstance(config.get("company"), dict) else {}
    goals = company.get("activeGoals", [])
    if not isinstance(goals, list):
        goals = []
    active: set[str] = set()
    schedules: list[dict] = []
    for item in goals:
        if isinstance(item, str):
            slug = item.strip()
            if slug and SLUG.match(slug):
                active.add(slug)
            continue
        if not isinstance(item, dict):
            continue
        template = item.get("template")
        every = item.get("every")
        if not isinstance(template, str) or not template.strip() or not SLUG.match(template.strip()):
            continue
        entry = {"template": template.strip()}
        if isinstance(every, str) and every.strip():
            entry["every"] = every.strip()
        if isinstance(item.get("idPrefix"), str) and item["idPrefix"].strip():
            entry["idPrefix"] = item["idPrefix"].strip()
        if isinstance(item.get("facts"), dict):
            entry["facts"] = item["facts"]
        schedules.append(entry)
    return active, schedules


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


def normalize_state_repo(raw: object, field: str = "state.repo") -> str:
  value = str(raw or "").strip()
  if value.startswith(("http://", "https://")):
    parsed = urlparse(value)
    if parsed.scheme != "https" or parsed.netloc != "github.com":
      raise RuntimeError(f"kody.config.json: {field} must be a GitHub repository URL")
    value = parsed.path.strip("/").removesuffix(".git")
  parts = value.split("/")
  if len(parts) != 2 or not all(parts) or not all(SLUG.match(part) for part in parts):
    raise RuntimeError(f"kody.config.json: {field} must be owner/repo or https://github.com/owner/repo")
  return value


def state_target(config: dict) -> tuple[str, str]:
  if LOCAL_MODE:
    return "__local__", ""
    github = config.get("github") if isinstance(config.get("github"), dict) else {}
    owner = github.get("owner")
    repo = github.get("repo")
    if not isinstance(owner, str) or not owner or not isinstance(repo, str) or not repo:
        name_with_owner = gh(["repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"]).strip()
        owner, repo = name_with_owner.split("/", 1)
  state = config.get("state") if isinstance(config.get("state"), dict) else {}
  state_repo = state.get("repo") or config.get("stateRepo") or f"{owner}/kody-state"
  state_path = state.get("path") or config.get("statePath") or repo
  return normalize_state_repo(state_repo), str(state_path).strip().strip("/")


def state_file_path(state_base: str, goal_id: str) -> str:
    prefix = f"{state_base}/" if state_base else ""
    return f"{prefix}goals/instances/{goal_id}/state.json"


def local_goal_path(goal_id: str) -> Path:
    return instances_dir / goal_id / "state.json"


def read_remote_json(state_repo: str, path: str) -> dict | None:
    try:
        meta = json.loads(gh(["api", f"/repos/{state_repo}/contents/{path}"]))
    except Exception as err:
        if is_not_found(err):
            return None
        raise
    content = meta.get("content")
    if not isinstance(content, str):
        return None
    text = base64.b64decode(content.replace("\n", "")).decode("utf-8")
    return json.loads(text)


def remote_goal_exists(state_repo: str, state_base: str, goal_id: str) -> bool:
    if LOCAL_MODE:
        return local_goal_path(goal_id).exists()
    return read_remote_json(state_repo, state_file_path(state_base, goal_id)) is not None


def persist_goal(state_repo: str, state_base: str, goal_id: str, state_text: str) -> None:
    if LOCAL_MODE:
        target = local_goal_path(goal_id)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(state_text)
        return
    path = state_file_path(state_base, goal_id)
    if remote_goal_exists(state_repo, state_base, goal_id):
        return
    payload = {
        "message": f"chore(goals): create {goal_id}",
        "content": base64.b64encode(state_text.encode("utf-8")).decode("ascii"),
    }
    try:
        gh(["api", "--method", "PUT", f"/repos/{state_repo}/contents/{path}", "--input", "-"], json.dumps(payload))
    except Exception as err:
        if "HTTP 409" in str(err) or "HTTP 422" in str(err):
            return
        raise


def create_instance_from_template(
    state_repo: str,
    state_base: str,
    template: str,
    goal_id: str,
    now: datetime,
    facts_patch: dict | None = None,
) -> bool:
    if remote_goal_exists(state_repo, state_base, goal_id):
        return False
    template_path = find_template(template)
    if template_path is None:
        raise RuntimeError(f"template {template} not found")
    data = json.loads(template_path.read_text())
    facts = data.get("facts") if isinstance(data.get("facts"), dict) else {}
    facts.update(facts_patch or {})
    data["kind"] = "instance"
    data["template"] = template
    data["sourceTemplate"] = template
    data["state"] = "active"
    data["facts"] = facts
    data.setdefault("createdAt", now.isoformat().replace("+00:00", "Z"))
    data["updatedAt"] = now.isoformat().replace("+00:00", "Z")
    state_text = json.dumps(data, indent=2, sort_keys=True) + "\n"
    persist_goal(state_repo, state_base, goal_id, state_text)
    return True


def list_goal_ids(state_repo: str, state_base: str) -> list[str]:
    if LOCAL_MODE:
        if not instances_dir.exists():
            return []
        return sorted(path.name for path in instances_dir.iterdir() if (path / "state.json").exists())
    base = f"{state_base}/goals/instances" if state_base else "goals/instances"
    try:
        entries = json.loads(gh(["api", f"/repos/{state_repo}/contents/{base}"]))
    except Exception as err:
        if is_not_found(err):
            return []
        raise
    if not isinstance(entries, list):
        return []
    return sorted(entry["name"] for entry in entries if entry.get("type") == "dir" and isinstance(entry.get("name"), str))


def read_goal_state(state_repo: str, state_base: str, goal_id: str) -> dict | None:
    if LOCAL_MODE:
        path = local_goal_path(goal_id)
        if not path.exists():
            return None
        return json.loads(path.read_text())
    return read_remote_json(state_repo, state_file_path(state_base, goal_id))


def schedule_prefix(schedule: dict) -> str:
    return str(schedule.get("idPrefix") or schedule["template"])


def schedule_key(schedule: dict) -> tuple[str, str]:
    return schedule["template"], schedule_prefix(schedule)


def goal_template(data: dict) -> str | None:
    template = data.get("template") or data.get("sourceTemplate") or data.get("templateId")
    return template if isinstance(template, str) else None


def is_managed_goal(data: dict) -> bool:
    return all(key in data for key in MANAGED_KEYS)


def is_scheduled_instance(goal_id: str, data: dict, schedule: dict) -> bool:
    template = goal_template(data)
    prefix = schedule_prefix(schedule)
    return template == schedule["template"] and goal_id.startswith(f"{prefix}-")


def parse_state_time(value: object) -> float:
    if not isinstance(value, str) or not value:
        return 0
    try:
        raw = value[:-1] + "+00:00" if value.endswith("Z") else value
        return datetime.fromisoformat(raw).timestamp()
    except Exception:
        return 0


def scheduled_instance_sort_key(goal_id: str) -> tuple[float, str]:
    data = goal_state_cache.get(goal_id)
    if not isinstance(data, dict):
        return 0, goal_id
    return parse_state_time(data.get("createdAt") or data.get("updatedAt")), goal_id


config = load_config()
active, schedules = active_goal_config(config)
if not active and not schedules:
    print("[goal-scheduler] no company.activeGoals configured")
    print("KODY_SKIP_AGENT=true")
    raise SystemExit(0)
state_repo, state_base = state_target(config)
now = now_utc()
created: list[str] = []
errors: list[str] = []
goal_ids = list_goal_ids(state_repo, state_base)
goal_state_cache: dict[str, dict | None] = {}
scheduled_recurring = [schedule for schedule in schedules if schedule.get("every")]


def cached_goal_state(goal_id: str) -> dict | None:
    if goal_id not in goal_state_cache:
        goal_state_cache[goal_id] = read_goal_state(state_repo, state_base, goal_id)
    return goal_state_cache[goal_id]


scheduled_active: dict[tuple[str, str], set[str]] = {}
for goal_id in goal_ids:
    try:
        data = cached_goal_state(goal_id)
    except Exception:
        continue
    if not isinstance(data, dict) or data.get("state") != "active" or not is_managed_goal(data):
        continue
    for schedule in scheduled_recurring:
        if is_scheduled_instance(goal_id, data, schedule):
            scheduled_active.setdefault(schedule_key(schedule), set()).add(goal_id)
scheduled_selected = {
    key: {sorted(ids, key=scheduled_instance_sort_key)[0]} for key, ids in scheduled_active.items() if ids
}
selected_scheduled_ids = {goal_id for ids in scheduled_selected.values() for goal_id in ids}

for goal_id in sorted(active):
    try:
        if create_instance_from_template(state_repo, state_base, goal_id, goal_id, now):
            created.append(goal_id)
    except Exception as err:
        errors.append(f"{goal_id}: {err}")

for schedule in schedules:
    every = schedule.get("every")
    if not every:
        active.add(schedule["template"])
        continue
    try:
        suffix = bucket_suffix(every, now)
        prefix = schedule_prefix(schedule)
        running = scheduled_selected.get(schedule_key(schedule), set())
        if running:
            active.update(running)
            print(
                f"[goal-scheduler] skip {schedule['template']}: "
                f"active scheduled instance already running ({', '.join(sorted(running))})"
            )
            continue
        goal_id = f"{prefix}-{suffix}"
        active.add(goal_id)
        facts = schedule.get("facts") if isinstance(schedule.get("facts"), dict) else {}
        if create_instance_from_template(state_repo, state_base, schedule["template"], goal_id, now, facts):
            created.append(goal_id)
    except Exception as err:
        errors.append(f"{schedule['template']}: {err}")

for goal_id in created:
    print(f"[goal-scheduler] created goal instance {goal_id}")
for error in errors:
    print(f"[goal-scheduler] schedule skipped: {error}")

goal_ids = sorted(set(goal_ids) | set(created))
if not goal_ids:
    print("[goal-scheduler] no goal instances yet")
    print("KODY_SKIP_AGENT=true")
    raise SystemExit(0)

active_count = 0
managed_active = 0
for goal_id in goal_ids:
    try:
        data = cached_goal_state(goal_id)
    except Exception as err:
        print(f"[goal-scheduler] skip {goal_id}: failed to read state ({err})")
        continue
    if not isinstance(data, dict):
        continue
    template = goal_template(data)
    activated = (
        goal_id in active
        or (isinstance(template, str) and template in active)
        or goal_id in selected_scheduled_ids
    )
    if not activated or data.get("state") != "active":
        continue
    active_count += 1
    managed = is_managed_goal(data)
    if not managed:
        print(f"[goal-scheduler] skip {goal_id}: legacy goal files are not managed-goal instances")
        continue
    managed_active += 1
    print(f"[goal-scheduler] -> tick {goal_id} (goal-manager)")
    result = subprocess.run(["kody-engine", "exec", "goal-manager", "--goal", goal_id], check=False)
    if result.returncode != 0:
        print(f"[goal-scheduler] tick {goal_id} failed (continuing)")

print(f"[goal-scheduler] scanned {len(goal_ids)} goal instance(s), active={active_count}, managed={managed_active}")
print("KODY_SKIP_AGENT=true")
PY
