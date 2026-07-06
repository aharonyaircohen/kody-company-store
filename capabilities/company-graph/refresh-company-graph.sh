#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

REPORT_SLUG="company-graph"
REPORT_FILE="reports/${REPORT_SLUG}.md"
STATE_REPO=""
REPORT_PATH=""
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

NODES="$TMP_DIR/nodes.json"
EDGES="$TMP_DIR/edges.json"
FINDINGS="$TMP_DIR/findings.json"
REPORT_BODY="$TMP_DIR/company-graph.md"
printf '[]\n' >"$NODES"
printf '[]\n' >"$EDGES"
printf '[]\n' >"$FINDINGS"

fail() {
  printf 'FAILED: %s\n' "$*"
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required"

resolve_state_report_target() {
  local consumer_repo owner name config state_path
  consumer_repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
  owner="${consumer_repo%%/*}"
  name="${consumer_repo#*/}"
  config="{}"
  [[ -f kody.config.json ]] && config="$(cat kody.config.json)"
  STATE_REPO="$(jq -r --arg default "$owner/kody-state" '.state.repo // .stateRepo // $default' <<<"$config")"
  state_path="$(jq -r --arg default "$name" '.state.path // .statePath // $default' <<<"$config")"
  state_path="${state_path#/}"
  state_path="${state_path%/}"
  REPORT_PATH="${state_path:+$state_path/}$REPORT_FILE"
}

slug_of() {
  local name
  name="$(basename "$1")"
  name="${name%.md}"
  name="${name%.json}"
  name="${name%.cjs}"
  name="${name%.sh}"
  printf '%s' "$name"
}

fm_value() {
  local file="$1"
  local key="$2"
  awk -v key="$key" '
    NR == 1 && $0 == "---" { front = 1; next }
    front && $0 == "---" { exit }
    front {
      line = $0
      sub(/\r$/, "", line)
      if (line ~ "^" key ":[[:space:]]*") {
        sub("^[^:]+:[[:space:]]*", "", line)
        gsub(/^[ "]+|[ "]+$/, "", line)
        print line
        exit
      }
    }
  ' "$file"
}

list_json() {
  jq -cn --arg s "${1:-}" '
    ($s | gsub("^\\s+|\\s+$"; "")) as $trimmed
    | if $trimmed == "" then []
      else
        ($trimmed | gsub("^\\["; "") | gsub("\\]$"; "") | split(",")
        | map(gsub("^\\s+|\\s+$"; "") | gsub("^\"|\"$"; ""))
        | map(select(length > 0)))
      end
  '
}

append_unique_json() {
  local file="$1"
  local item="$2"
  local tmp="$file.tmp"
  jq --argjson item "$item" '
    if any(.[]; .id == $item.id) then . else . + [$item] end
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

add_node() {
  append_unique_json "$NODES" "$1"
}

add_edge() {
  local from="$1"
  local to="$2"
  local relation="$3"
  [[ -n "$from" && -n "$to" ]] || return 0
  local item
  item="$(jq -nc \
    --arg from "$from" \
    --arg to "$to" \
    --arg relation "$relation" \
    '{id: ($from + "->" + $relation + "->" + $to), from: $from, to: $to, relation: $relation}')"
  append_unique_json "$EDGES" "$item"
}

add_finding() {
  local id="$1"
  local severity="$2"
  local title="$3"
  local data="${4:-}"
  [[ -n "$data" ]] || data="{}"
  local item
  item="$(jq -nc \
    --arg id "$id" \
    --arg severity "$severity" \
    --arg title "$title" \
    --argjson data "$data" \
    '{id: $id, severity: $severity, title: $title, data: $data}')"
  append_unique_json "$FINDINGS" "$item"
}

ref_id() {
  local ref="${1:-}"
  local preferred="${2:-}"
  local clean slug rest
  clean="$(printf '%s' "$ref" | sed -E 's/^[[:space:]"'\'']+//; s/[[:space:]"'\'']+$//')"
  [[ -n "$clean" ]] || return 0
  if [[ "$clean" == goal:* ]]; then
    printf 'goal:%s' "${clean#goal:}"
    return 0
  fi
  slug="$(basename "${clean%.md}")"
  case "$clean" in
    .kody/capabilities/*|capabilities/*)
      rest="${clean#./}"
      rest="${rest#.kody/capabilities/}"
      rest="${rest#capabilities/}"
      printf 'capability:%s' "${rest%%/*}"
      return 0
      ;;
    .kody/context/*|context/*) printf 'context:%s' "$slug"; return 0 ;;
    .kody/agents/*|agent/*) printf 'agent:%s' "$slug"; return 0 ;;
    .kody/scripts/*|scripts/*) printf 'script:%s' "$slug"; return 0 ;;
    reports/*) printf 'report:%s' "$slug"; return 0 ;;
  esac
  if [[ -n "$preferred" ]]; then
    printf '%s:%s' "$preferred" "$slug"
  else
    printf 'external:%s' "$clean"
  fi
}

hash_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

decode_base64() {
  if base64 --help 2>&1 | grep -q -- '--decode'; then
    base64 --decode
  else
    base64 -D
  fi
}

current_report_hash() {
  [[ -f "$REPORT_PATH" ]] || return 0
  grep -Eo 'graphHash[" ]*[:=][ "]*[a-f0-9]{64}|Graph hash: `?[a-f0-9]{64}' "$REPORT_PATH" \
    | grep -Eo '[a-f0-9]{64}' \
    | head -n 1 || true
}

is_rate_limit() {
  grep -Eiq 'rate limit|secondary rate limit|API rate limit exceeded' "$1"
}

agent_slugs=()
if compgen -G ".kody/agents/*.md" >/dev/null; then
  for file in .kody/agents/*.md; do
    slug="$(slug_of "$file")"
    agent_slugs+=("$slug")
    heading_count="$(grep -cE '^#{1,6} ' "$file" || true)"
    add_node "$(jq -nc \
      --arg id "agent:$slug" \
      --arg slug "$slug" \
      --argjson headingCount "$heading_count" \
      '{id: $id, type: "agent", slug: $slug, headingCount: $headingCount}')"
  done
fi

if compgen -G ".kody/context/*.md" >/dev/null; then
  for file in .kody/context/*.md; do
    slug="$(slug_of "$file")"
    audience="$(list_json "$(fm_value "$file" agent)")"
    heading_count="$(grep -cE '^#{1,6} ' "$file" || true)"
    add_node "$(jq -nc \
      --arg id "context:$slug" \
      --arg slug "$slug" \
      --argjson agent "$audience" \
      --argjson headingCount "$heading_count" \
      '{id: $id, type: "context", slug: $slug, agent: $agent, headingCount: $headingCount}')"

    if jq -e 'index("*") != null' >/dev/null <<<"$audience"; then
      for agent in "${agent_slugs[@]}"; do
        add_edge "context:$slug" "agent:$agent" "audience"
      done
    else
      while IFS= read -r agent; do
        [[ -n "$agent" ]] && add_edge "context:$slug" "$(ref_id "$agent" agent)" "audience"
      done < <(jq -r '.[]' <<<"$audience")
    fi
  done
fi

if [[ -d ".kody/capabilities" ]]; then
  while IFS= read -r dir; do
    slug="$(basename "$dir")"
    profile="$dir/profile.json"
    body="$dir/capability.md"
    [[ -f "$profile" && -f "$body" ]] || continue
    if ! jq empty "$profile" >/dev/null 2>&1; then
      continue
    fi

    agent="$(jq -r '.agent // ""' "$profile")"
    implementations="$(jq -c '
      def list($x):
        if $x == null then []
        elif ($x | type) == "array" then [$x[] | select(type == "string" and length > 0)]
        elif ($x | type) == "string" and ($x | length) > 0 then [$x]
        else [] end;
      (list(.implementation) + list(.implementations)) | unique
    ' "$profile")"
    reads_from="$(jq -c '
      def list($x):
        if $x == null then []
        elif ($x | type) == "array" then [$x[] | select(type == "string" and length > 0)]
        elif ($x | type) == "string" and ($x | length) > 0 then [$x]
        else [] end;
      (list(.readsFrom) + list(.reads_from)) | unique
    ' "$profile")"
    writes_to="$(jq -c '
      def list($x):
        if $x == null then []
        elif ($x | type) == "array" then [$x[] | select(type == "string" and length > 0)]
        elif ($x | type) == "string" and ($x | length) > 0 then [$x]
        else [] end;
      (list(.writesTo) + list(.writes_to)) | unique
    ' "$profile")"
    disabled="$(jq -r 'if .disabled == true then "true" else "false" end' "$profile")"
    internal="$(jq -r 'if .internal == true then "true" else "false" end' "$profile")"
    role="$(jq -r '.role // ""' "$profile")"
    kind="$(jq -r '.kind // ""' "$profile")"
    skills="$(jq -c '[.claudeCode.skills[]? | select(type == "string" and length > 0)]' "$profile")"
    shell_scripts="$(jq -c '[.scripts.preflight[]? | .shell? | select(type == "string" and length > 0)]' "$profile")"

    add_node "$(jq -nc \
      --arg id "capability:$slug" \
      --arg slug "$slug" \
      --arg agent "$agent" \
      --arg role "$role" \
      --arg kind "$kind" \
      --argjson implementations "$implementations" \
      --argjson readsFrom "$reads_from" \
      --argjson writesTo "$writes_to" \
      --argjson disabled "$disabled" \
      --argjson internal "$internal" \
      --argjson skills "$skills" \
      --argjson shellScripts "$shell_scripts" \
      '{id: $id, type: "capability", slug: $slug, agent: $agent, role: $role, kind: $kind, implementations: $implementations, readsFrom: $readsFrom, writesTo: $writesTo, disabled: $disabled, internal: $internal, skills: $skills, shellScripts: $shellScripts}')"

    add_edge "capability:$slug" "$(ref_id "$agent" agent)" "assigned_to"
    while IFS= read -r implementation; do
      [[ -n "$implementation" ]] && add_edge "capability:$slug" "$(ref_id "$implementation" capability)" "runs"
    done < <(jq -r '.[]' <<<"$implementations")
    while IFS= read -r source; do
      [[ -n "$source" ]] && add_edge "capability:$slug" "$(ref_id "$source" context)" "reads_from"
    done < <(jq -r '.[]' <<<"$reads_from")
    while IFS= read -r target; do
      [[ -n "$target" ]] && add_edge "capability:$slug" "$(ref_id "$target" report)" "writes_to"
    done < <(jq -r '.[]' <<<"$writes_to")
    while IFS= read -r skill; do
      [[ -n "$skill" ]] || continue
      add_node "$(jq -nc \
        --arg id "skill:$slug/$skill" \
        --arg slug "$slug/$skill" \
        --arg name "$skill" \
        --arg path ".kody/capabilities/$slug/skills/$skill/SKILL.md" \
        '{id: $id, type: "skill", slug: $slug, name: $name, path: $path, scope: "capability"}')"
      add_edge "capability:$slug" "skill:$slug/$skill" "uses_skill"
    done < <(jq -r '.[]' <<<"$skills")
    while IFS= read -r script; do
      [[ -n "$script" ]] || continue
      add_node "$(jq -nc \
        --arg id "script:$slug/$script" \
        --arg slug "$slug/$script" \
        --arg path ".kody/capabilities/$slug/$script" \
        '{id: $id, type: "script", slug: $slug, path: $path, scope: "capability"}')"
      add_edge "capability:$slug" "script:$slug/$script" "runs_preflight"
    done < <(jq -r '.[]' <<<"$shell_scripts")
  done < <(find .kody/capabilities -mindepth 1 -maxdepth 1 -type d | sort)
fi

if [[ -d ".kody/scripts" ]]; then
  while IFS= read -r file; do
    slug="$(slug_of "$file")"
    add_node "$(jq -nc \
      --arg id "script:$slug" \
      --arg slug "$slug" \
      --arg path "$file" \
      '{id: $id, type: "script", slug: $slug, path: $path, scope: "repo"}')"
  done < <(find .kody/scripts -maxdepth 1 -type f | sort)
fi

rate_limited=0
goal_issues='[]'
if command -v gh >/dev/null 2>&1; then
  if raw="$(gh issue list --state all --limit 200 --json number,title,labels,state 2>"$TMP_DIR/gh.err")"; then
    goal_issues="$(jq -c '
      [.[] | select(any(.labels[]?; (.name // "" | startswith("goal:"))))
      | {number, title, state, goals: [.labels[]?.name | select(startswith("goal:"))]}]
    ' <<<"$raw")"
  elif is_rate_limit "$TMP_DIR/gh.err"; then
    rate_limited=1
  fi
fi

while IFS= read -r issue; do
  number="$(jq -r '.number' <<<"$issue")"
  title="$(jq -r '.title' <<<"$issue")"
  state="$(jq -r '.state' <<<"$issue")"
  add_node "$(jq -nc \
    --arg id "issue:$number" \
    --argjson number "$number" \
    --arg title "$title" \
    --arg state "$state" \
    '{id: $id, type: "issue", number: $number, title: $title, state: $state}')"
  while IFS= read -r goal; do
    [[ -n "$goal" ]] || continue
    goal_slug="${goal#goal:}"
    add_node "$(jq -nc \
      --arg id "goal:$goal_slug" \
      --arg slug "$goal_slug" \
      --arg label "$goal" \
      '{id: $id, type: "goal", slug: $slug, label: $label}')"
    add_edge "issue:$number" "goal:$goal_slug" "labeled"
  done < <(jq -r '.goals[]?' <<<"$issue")
done < <(jq -c '.[]' <<<"$goal_issues")

while IFS= read -r edge_to; do
  if jq -e --arg id "$edge_to" 'any(.[]; .id == $id)' "$NODES" >/dev/null; then
    continue
  fi
  type="${edge_to%%:*}"
  slug="${edge_to#*:}"
  add_node "$(jq -nc \
    --arg id "$edge_to" \
    --arg type "$type" \
    --arg slug "$slug" \
    '{id: $id, type: $type, slug: $slug, missing: true}')"
done < <(jq -r '.[].to' "$EDGES" | sort -u)

coverage_gaps="$(
  if [[ -d ".kody" ]]; then
    find .kody -mindepth 1 -maxdepth 1 -type d -exec basename {} \; \
      | grep -Ev '^(context|capabilities|agent|implementations|reports|scripts)$' \
      | sort \
      | jq -Rsc 'split("\n") | map(select(length > 0))'
  else
    printf '[]'
  fi
)"

nodes_sorted="$(jq -c 'sort_by(.id)' "$NODES")"
edges_sorted="$(jq -c 'sort_by(.id)' "$EDGES")"
graph="$(jq -nc \
  --argjson nodes "$nodes_sorted" \
  --argjson edges "$edges_sorted" \
  --argjson coverageGaps "$coverage_gaps" \
  '{schemaVersion: 1, nodes: $nodes, edges: $edges, coverageGaps: $coverageGaps}')"
graph_hash="$(printf '%s' "$graph" | jq -S -c . | hash_stdin)"
previous_hash="$(current_report_hash)"

if [[ "$previous_hash" == "$graph_hash" ]]; then
  printf 'DONE\nCOMMIT_MSG: chore(reports): refresh company-graph\nPR_SUMMARY:\n- No report write needed; company graph was unchanged.\n'
  exit 0
fi

node_counts="$(jq -nc --argjson nodes "$nodes_sorted" --argjson goalIssues "$goal_issues" '
  def count_type($t): [$nodes[] | select(.type == $t)] | length;
  {
    context: count_type("context"),
    capabilities: count_type("capability"),
    agent: count_type("agent"),
    implementations: count_type("implementation"),
    scripts: count_type("script"),
    skills: count_type("skill"),
    reports: count_type("report"),
    goals: count_type("goal"),
    issues: ($goalIssues | length)
  }
')"
add_finding "company-graph.snapshot" "low" "Graph snapshot emitted" \
  "$(jq -nc --arg graphHash "$graph_hash" --argjson nodeCounts "$node_counts" \
    '{nodeCounts: $nodeCounts, graphHash: $graphHash}')"

while IFS=$'\t' read -r id slug; do
  if ! jq -e --arg id "$id" '
    any(.[]; .to == $id and (.relation == "assigned_to" or .relation == "runs_as" or .relation == "audience"))
  ' "$EDGES" >/dev/null; then
    add_finding "company-graph.orphan-agent.$slug" "medium" \
      "$slug - no capability, context, or implementation references it" \
      "$(jq -nc --arg agent "$slug" '{agent: $agent}')"
  fi
done < <(jq -r '.[] | select(.type == "agent") | [.id, .slug] | @tsv' "$NODES")

while IFS=$'\t' read -r id slug; do
  if ! jq -e --arg id "$id" 'any(.[]; .to == $id and .relation == "reads_from")' "$EDGES" >/dev/null; then
    add_finding "company-graph.stale-context.$slug" "low" \
      "$slug - not declared as reads_from by any capability" \
      "$(jq -nc --arg context "$slug" '{context: $context}')"
  fi
done < <(jq -r '.[] | select(.type == "context") | [.id, .slug] | @tsv' "$NODES")

while IFS=$'\t' read -r id slug; do
  referenced_by="$(jq -r --arg id "$id" '
    [.[] | select(.to == $id and .relation == "reads_from") | (.from | sub("^capability:"; ""))]
    | unique
    | join(",")
  ' "$EDGES")"
  if [[ -n "$referenced_by" ]]; then
    data="$(jq -nc --arg slug "$slug" --arg refs "$referenced_by" \
      '{slug: $slug, referencedBy: ($refs | split(",") | map(select(length > 0)))}')"
    add_finding "company-graph.disabled-but-referenced.$slug" "high" \
      "$slug - disabled but named in another capability's reads_from" \
      "$data"
  fi
done < <(jq -r '.[] | select(.type == "capability" and .disabled == true) | [.id, .slug] | @tsv' "$NODES")

while IFS= read -r subfolder; do
  [[ -n "$subfolder" ]] || continue
  add_finding "company-graph.coverage-gap.$subfolder" "low" \
    "$subfolder - present in .kody/ but has no nodes" \
    "$(jq -nc --arg subfolder ".kody/$subfolder" '{subfolder: $subfolder}')"
done < <(jq -r '.[]' <<<"$coverage_gaps")

if [[ "$rate_limited" == "1" ]]; then
  add_finding "company-graph.rate-limited" "low" \
    "Skipped issue scan - gh rate limit hit during refresh" \
    "$(jq -nc --arg graphHash "$graph_hash" '{graphHash: $graphHash}')"
fi

generated_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
{
  printf '%s\n' "---"
  printf '%s\n' "slug: company-graph"
  printf '%s\n' "capabilitySlug: company-graph"
  printf 'generatedAt: "%s"\n' "$generated_at"
  printf '%s\n' "findings:"
  jq -r '.[] | "  - id: \(.id)\n    severity: \(.severity)\n    title: \(.title | @json)\n    data: \(.data | tojson)"' "$FINDINGS"
  printf '%s\n\n' "---"
  printf '%s\n\n' "# Company Graph"
  printf '%s\n' "| Node type | Count |"
  printf '%s\n' "|---|---:|"
  jq -r 'to_entries[] | "| \(.key) | \(.value) |"' <<<"$node_counts"
  printf '\nGraph hash: `%s`\n\n' "$graph_hash"
  printf '%s\n' "## Graph"
  printf '%s\n' '```json'
  jq . <<<"$graph"
  printf '%s\n' '```'
} >"$REPORT_BODY"

finding_count="$(jq 'length' "$FINDINGS")"
if [[ "$DRY_RUN" == "1" ]]; then
  printf 'DONE\nCOMMIT_MSG: chore(reports): refresh company-graph\nPR_SUMMARY:\n- Dry run only; no report write attempted.\n- Findings: %s.\n' "$finding_count"
  exit 0
fi

command -v gh >/dev/null 2>&1 || fail "gh is required"
resolve_state_report_target

read_remote_report() {
  gh api "/repos/$STATE_REPO/contents/$REPORT_PATH" 2>/dev/null || true
}

remote_json="$(read_remote_report)"
remote_sha=""
remote_hash=""
if [[ -n "$remote_json" ]]; then
  remote_sha="$(jq -r '.sha // ""' <<<"$remote_json")"
  remote_hash="$(
    jq -r '.content // ""' <<<"$remote_json" \
      | tr -d '\n' \
      | decode_base64 2>/dev/null \
      | grep -Eo 'graphHash[" ]*[:=][ "]*[a-f0-9]{64}|Graph hash: `?[a-f0-9]{64}' \
      | grep -Eo '[a-f0-9]{64}' \
      | head -n 1 || true
  )"
fi

if [[ "$remote_hash" == "$graph_hash" ]]; then
  printf 'DONE\nCOMMIT_MSG: chore(reports): refresh company-graph\nPR_SUMMARY:\n- No report write needed; company graph was unchanged.\n'
  exit 0
fi

put_report() {
  local sha="${1:-}"
  local content
  content="$(base64 <"$REPORT_BODY" | tr -d '\n')"
  local args=(
    api
    -X PUT
    "/repos/$STATE_REPO/contents/$REPORT_PATH"
    -f "message=chore(reports): refresh company-graph"
    -f "content=$content"
  )
  if [[ -n "$sha" ]]; then
    args+=(-f "sha=$sha")
  fi
  gh "${args[@]}"
}

if ! put_report "$remote_sha" 2>"$TMP_DIR/put.err"; then
  if grep -Eiq '409|sha' "$TMP_DIR/put.err"; then
    remote_json="$(read_remote_report)"
    remote_sha="$(jq -r '.sha // ""' <<<"$remote_json")"
    remote_hash="$(
      jq -r '.content // ""' <<<"$remote_json" \
        | tr -d '\n' \
        | decode_base64 2>/dev/null \
        | grep -Eo 'graphHash[" ]*[:=][ "]*[a-f0-9]{64}|Graph hash: `?[a-f0-9]{64}' \
        | grep -Eo '[a-f0-9]{64}' \
        | head -n 1 || true
    )"
    if [[ "$remote_hash" == "$graph_hash" ]]; then
      printf 'DONE\nCOMMIT_MSG: chore(reports): refresh company-graph\nPR_SUMMARY:\n- No report write needed; company graph was unchanged.\n'
      exit 0
    fi
    put_report "$remote_sha" >/dev/null
  else
    fail "$(cat "$TMP_DIR/put.err")"
  fi
fi

printf 'DONE\nCOMMIT_MSG: chore(reports): refresh company-graph\nPR_SUMMARY:\n- Refreshed %s in %s.\n- Findings: %s.\n' "$REPORT_PATH" "$STATE_REPO" "$finding_count"
