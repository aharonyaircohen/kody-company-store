"""Managed-goal todo state contract for goal-scheduler.

The scheduler owns timing and dispatch. This module owns the todo markdown
shape used for managed goal state.
"""

import json
import re


def parse_frontmatter_value(raw: str) -> object:
    value = raw.strip()
    if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
        value = value[1:-1].replace('\\"', '"').replace("\\\\", "\\")
    if value == "true":
        return True
    if value == "false":
        return False
    if value == "null":
        return None
    if value.startswith(("{", "[")) or re.match(r"^-?\d+(\.\d+)?$", value):
        try:
            return json.loads(value)
        except Exception:
            pass
    return value


def serialize_frontmatter_value(value: object) -> str:
    if isinstance(value, str):
        text = value
    else:
        text = json.dumps(value, separators=(",", ":"))
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def parse_todo_items(text: str) -> list[dict]:
    match = re.search(r"<!--\s*kody-todo-items-json\s*\n([\s\S]*?)\n-->", text)
    if not match:
        return []
    try:
        items = json.loads(match.group(1))
    except Exception:
        return []
    return [item for item in items if isinstance(item, dict)] if isinstance(items, list) else []


def parse_todo_frontmatter(text: str) -> dict:
    match = re.match(r"---\r?\n([\s\S]*?)\r?\n---", text)
    if not match:
        return {}
    parsed: dict = {}
    for raw_line in match.group(1).splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        key, value = line.split(":", 1)
        parsed[key.strip()] = parse_frontmatter_value(value)
    return parsed


def is_managed_todo_text(text: str) -> bool:
    frontmatter = parse_todo_frontmatter(text)
    return (
        frontmatter.get("managed") is True
        or frontmatter.get("managed") == "true"
        or frontmatter.get("managedModel") in ("agentGoal", "agentLoop")
    )


def todo_description(text: str) -> str:
    without_frontmatter = re.sub(r"^---\r?\n[\s\S]*?\r?\n---\r?\n?", "", text, count=1)
    return re.sub(r"<!--\s*kody-todo-items-json\s*\n[\s\S]*?\n-->", "", without_frontmatter).strip()


def string_list(value: object) -> list[str]:
    return [item for item in value if isinstance(item, str)] if isinstance(value, list) else []


def route_from_items(items: list[dict]) -> list[dict]:
    route: list[dict] = []
    for item in items:
        meta = item.get("meta") if isinstance(item.get("meta"), dict) else {}
        stage = meta.get("stage")
        evidence = meta.get("evidence") or item.get("id")
        capability = meta.get("capability")
        if isinstance(stage, str) and isinstance(evidence, str) and isinstance(capability, str):
            step = {"stage": stage, "evidence": evidence, "capability": capability}
            if isinstance(meta.get("args"), dict):
                step["args"] = meta["args"]
            if meta.get("saveReport") is True:
                step["saveReport"] = True
            route.append(step)
    return route


def parse_todo_goal_state(goal_id: str, text: str) -> dict:
    frontmatter = parse_todo_frontmatter(text)
    items = parse_todo_items(text)
    raw_destination = frontmatter.get("destination") if isinstance(frontmatter.get("destination"), dict) else {}
    route = frontmatter.get("route") if isinstance(frontmatter.get("route"), list) else route_from_items(items)
    evidence = string_list(raw_destination.get("evidence")) or string_list(frontmatter.get("evidence"))
    if not evidence:
        evidence = [
            str((item.get("meta") if isinstance(item.get("meta"), dict) else {}).get("evidence") or item.get("id"))
            for item in items
            if item.get("id")
        ]
    facts = frontmatter.get("facts") if isinstance(frontmatter.get("facts"), dict) else {}
    facts = dict(facts)
    for item in items:
        meta = item.get("meta") if isinstance(item.get("meta"), dict) else {}
        key = meta.get("evidence") or item.get("id")
        if isinstance(key, str):
            facts[key] = item.get("completed") is True
    capabilities = string_list(frontmatter.get("capabilities"))
    if not capabilities:
        capabilities = [step["capability"] for step in route if isinstance(step.get("capability"), str)]
    data = dict(frontmatter)
    data.update(
        {
            "id": goal_id,
            "version": frontmatter.get("version", 1),
            "state": frontmatter.get("state", "active"),
            "type": frontmatter.get("type", "general"),
            "destination": {**raw_destination, "outcome": todo_description(text), "evidence": evidence},
            "capabilities": capabilities,
            "route": route,
            "facts": facts,
            "blockers": string_list(frontmatter.get("blockers")),
        }
    )
    return data


def todo_items_from_state(data: dict, now: str) -> list[dict]:
    destination = data.get("destination") if isinstance(data.get("destination"), dict) else {}
    evidence = string_list(destination.get("evidence"))
    route = data.get("route") if isinstance(data.get("route"), list) else []
    facts = data.get("facts") if isinstance(data.get("facts"), dict) else {}
    route_by_evidence = {
        step.get("evidence"): step
        for step in route
        if isinstance(step, dict) and isinstance(step.get("evidence"), str)
    }
    if evidence:
        items = []
        for key in evidence:
            step = route_by_evidence.get(key) if isinstance(route_by_evidence.get(key), dict) else {}
            completed = facts.get(key) is True
            items.append(
                {
                    "id": key,
                    "title": step.get("stage") if isinstance(step.get("stage"), str) else key,
                    "body": "",
                    "assignee": None,
                    "completed": completed,
                    "createdAt": data.get("createdAt") if isinstance(data.get("createdAt"), str) else now,
                    "completedAt": data.get("updatedAt") if completed and isinstance(data.get("updatedAt"), str) else None,
                    "meta": {
                        "evidence": key,
                        **({"stage": step["stage"]} if isinstance(step.get("stage"), str) else {}),
                        **({"capability": step["capability"]} if isinstance(step.get("capability"), str) else {}),
                        **({"args": step["args"]} if isinstance(step.get("args"), dict) else {}),
                        **({"saveReport": True} if step.get("saveReport") is True else {}),
                    },
                }
            )
        return items
    return [
        {
            "id": capability,
            "title": capability,
            "body": "",
            "assignee": None,
            "completed": False,
            "createdAt": data.get("createdAt") if isinstance(data.get("createdAt"), str) else now,
            "completedAt": None,
            "meta": {"capability": capability},
        }
        for capability in string_list(data.get("capabilities"))
    ]


def serialize_todo_goal_state(goal_id: str, data: dict, now: str) -> str:
    destination = data.get("destination") if isinstance(data.get("destination"), dict) else {}
    outcome = destination.get("outcome") if isinstance(destination.get("outcome"), str) else ""
    frontmatter = dict(data)
    frontmatter.pop("destination", None)
    frontmatter["id"] = goal_id
    frontmatter["title"] = goal_id
    frontmatter["managed"] = True
    frontmatter["managedModel"] = "agentLoop" if frontmatter.get("scheduleMode") == "agentLoop" or frontmatter.get("type") == "agentLoop" else "agentGoal"
    frontmatter["evidence"] = string_list(destination.get("evidence"))
    lines = ["---"]
    for key, value in frontmatter.items():
        if value is not None:
            lines.append(f"{key}: {serialize_frontmatter_value(value)}")
    lines.extend(["---", "", outcome, "", "<!-- kody-todo-items-json", json.dumps(todo_items_from_state(data, now), indent=2), "-->", ""])
    return "\n".join(lines)
