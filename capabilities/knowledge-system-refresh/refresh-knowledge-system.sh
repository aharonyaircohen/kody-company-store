set -euo pipefail

fail() {
  printf 'FAILED: %s\n' "$*"
  exit 1
}

for tool in gh git jq curl uv; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is required"
done

REPOSITORY="${GITHUB_REPOSITORY:-}"
if [[ -z "$REPOSITORY" ]]; then
  REPOSITORY="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi
[[ "$REPOSITORY" == */* ]] || fail "Could not resolve the consumer repository"
OWNER="${REPOSITORY%%/*}"
REPO="${REPOSITORY#*/}"
AUTH_TOKEN="${KODY_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
[[ -n "$AUTH_TOKEN" ]] || fail "KODY_TOKEN, GH_TOKEN, or GITHUB_TOKEN is required"

KODY_DASHBOARD_URL="${KODY_DASHBOARD_URL:-https://kody-dashboard-khaki.vercel.app}"
KODY_DASHBOARD_URL="${KODY_DASHBOARD_URL%/}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
GRAPHIFY_DIR="$TMP_DIR/graphify"
EXPORT_FILE="$TMP_DIR/kody-backend.json"
ISSUES_FILE="$TMP_DIR/issues.json"
PRS_FILE="$TMP_DIR/pull-requests.json"
BUSINESS_FILE="$TMP_DIR/business-graph.json"
GRAPH_FILE="$TMP_DIR/graph.json"
REPORT_FILE="$TMP_DIR/GRAPH_REPORT.md"

auth_args=(
  -H "x-kody-token: $AUTH_TOKEN"
  -H "x-kody-owner: $OWNER"
  -H "x-kody-repo: $REPO"
)

# Reliable CI base: deterministic local AST extraction with no model or API key.
uvx --from graphifyy graphify extract . \
  --code-only \
  --no-cluster \
  --out "$GRAPHIFY_DIR" >/dev/null

BASE_GRAPH="$GRAPHIFY_DIR/graphify-out/graph.json"
[[ -s "$BASE_GRAPH" ]] || fail "Graphify did not produce graph.json"

curl --fail --silent --show-error \
  "${auth_args[@]}" \
  "$KODY_DASHBOARD_URL/api/kody/company/backend/export" \
  >"$EXPORT_FILE"

gh issue list --repo "$REPOSITORY" --state all --limit 500 \
  --json number,title,state,labels,assignees,milestone,url,createdAt,updatedAt \
  >"$ISSUES_FILE"
gh pr list --repo "$REPOSITORY" --state all --limit 500 \
  --json number,title,state,isDraft,baseRefName,headRefName,labels,author,url,createdAt,updatedAt \
  >"$PRS_FILE"

# Only business and operational tables enter the graph. Raw chat data is
# intentionally excluded: conversationEntries, conversationTurns, chatEvents,
# conversationAttachments, and all user-private/global state stay out.
jq -n \
  --arg repository "$REPOSITORY" \
  --slurpfile backend "$EXPORT_FILE" \
  --slurpfile issues "$ISSUES_FILE" \
  --slurpfile prs "$PRS_FILE" '
  def selected_tables: [
    "definitionHeads", "definitionVersions", "catalog", "workflows",
    "workflowRuns", "userJourneys", "userJourneyVersions", "userJourneyRuns",
    "intents", "intentDecisions", "goals", "reports", "agents", "macros",
    "agencyRecords", "taskState", "capabilityState", "dailyLogs",
    "agencyRuns", "runEvents", "manifests", "inboxEntries"
  ];
  def key_for($row):
    ($row.slug // $row.intentId // $row.goalId // $row.workflowId //
     $row.journeyId // $row.runId // $row.recordId // $row.taskKey //
     $row.entryId // $row.macroId // $row._id // "record") | tostring;
  def label_for($row; $fallback):
    ($row.title // $row.name // $row.label // $row.slug // $row.summary // $fallback) | tostring;
  def domain_for($table):
    if ($table | test("intent|goal"; "i")) then "business"
    elif ($table | test("agent|capability|workflow|agency|macro"; "i")) then "agency"
    elif ($table | test("journey"; "i")) then "quality"
    elif ($table | test("run|task|inbox"; "i")) then "work"
    elif ($table | test("report|manifest|definition|catalog"; "i")) then "knowledge"
    else "other" end;
  ($backend[0].tables // {}) as $tables |
  ([selected_tables[] as $table |
    ($tables[$table] // [])[] as $row |
    (key_for($row)) as $key |
    {
      id: ("kody:" + $table + ":" + $key),
      label: label_for($row; $key),
      type: $table,
      domain: domain_for($table),
      description: (($row.status // $row.state // $row.kind // "") | tostring),
      source: "kody"
    }
  ]) as $kodyNodes |
  ([($issues[0] // [])[] | {
    id: ("github:issue:" + (.number | tostring)),
    label: .title,
    type: "issue",
    domain: "work",
    description: .state,
    resource: .url,
    source: "github"
  }]) as $issueNodes |
  ([($prs[0] // [])[] | {
    id: ("github:pr:" + (.number | tostring)),
    label: .title,
    type: "pull_request",
    domain: "work",
    description: .state,
    resource: .url,
    source: "github"
  }]) as $prNodes |
  ($kodyNodes + $issueNodes + $prNodes) as $nodes |
  {
    nodes: ([{
      id: ("repo:" + $repository),
      label: $repository,
      type: "repository",
      domain: "project",
      source: "github"
    }] + $nodes),
    edges: [$nodes[] | {
      source: ("repo:" + $repository),
      target: .id,
      relation: "contains",
      confidence: "EXTRACTED"
    }]
  }
' >"$BUSINESS_FILE"

jq -s '
  .[0] as $code |
  .[1] as $business |
  ($code.edges // $code.links // []) as $codeEdges |
  {
    directed: ($code.directed // true),
    multigraph: ($code.multigraph // false),
    graph: ($code.graph // {}),
    nodes: (($code.nodes // []) + $business.nodes | unique_by(.id)),
    edges: ($codeEdges + $business.edges)
  }
' "$BASE_GRAPH" "$BUSINESS_FILE" >"$GRAPH_FILE"

NODE_COUNT="$(jq '.nodes | length' "$GRAPH_FILE")"
EDGE_COUNT="$(jq '.edges | length' "$GRAPH_FILE")"
GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
SOURCE_REVISION="$(git rev-parse HEAD)"
KODY_COUNT="$(jq '[.nodes[] | select(.source == "kody")] | length' "$GRAPH_FILE")"
ISSUE_COUNT="$(jq '[.nodes[] | select(.type == "issue")] | length' "$GRAPH_FILE")"
PR_COUNT="$(jq '[.nodes[] | select(.type == "pull_request")] | length' "$GRAPH_FILE")"

{
  printf '# Knowledge System\n\n'
  printf -- '- Repository: `%s`\n' "$REPOSITORY"
  printf -- '- Generated: `%s`\n' "$GENERATED_AT"
  printf -- '- Source revision: `%s`\n' "$SOURCE_REVISION"
  printf -- '- Nodes: %s\n' "$NODE_COUNT"
  printf -- '- Edges: %s\n' "$EDGE_COUNT"
  printf -- '- Kody business records: %s\n' "$KODY_COUNT"
  printf -- '- GitHub issues: %s\n' "$ISSUE_COUNT"
  printf -- '- GitHub pull requests: %s\n' "$PR_COUNT"
} >"$REPORT_FILE"

create_upload() {
  curl --fail --silent --show-error -X POST \
    "${auth_args[@]}" \
    "$KODY_DASHBOARD_URL/api/kody/knowledge-system" \
    | jq -er '.uploadUrl'
}

upload_file() {
  local file="$1"
  local content_type="$2"
  local upload_url
  upload_url="$(create_upload)"
  curl --fail --silent --show-error -X POST \
    -H "Content-Type: $content_type" \
    --data-binary "@$file" \
    "$upload_url" \
    | jq -er '.storageId'
}

GRAPH_STORAGE_ID="$(upload_file "$GRAPH_FILE" "application/json")"
REPORT_STORAGE_ID="$(upload_file "$REPORT_FILE" "text/markdown; charset=utf-8")"

publish_body="$(jq -nc \
  --arg graphStorageId "$GRAPH_STORAGE_ID" \
  --arg reportStorageId "$REPORT_STORAGE_ID" \
  --arg generatedAt "$GENERATED_AT" \
  --arg sourceRevision "$SOURCE_REVISION" \
  --argjson nodeCount "$NODE_COUNT" \
  --argjson edgeCount "$EDGE_COUNT" \
  '{
    graphStorageId: $graphStorageId,
    reportStorageId: $reportStorageId,
    generatedAt: $generatedAt,
    sourceRevision: $sourceRevision,
    nodeCount: $nodeCount,
    edgeCount: $edgeCount,
    schemaVersion: 1
  }')"

curl --fail --silent --show-error -X PUT \
  "${auth_args[@]}" \
  -H "Content-Type: application/json" \
  --data "$publish_body" \
  "$KODY_DASHBOARD_URL/api/kody/knowledge-system" \
  | jq -e '.ok == true' >/dev/null

printf 'DONE\nCOMMIT_MSG: chore(knowledge): refresh knowledge system\nPR_SUMMARY:\n- Published %s nodes and %s edges for %s.\n' \
  "$NODE_COUNT" "$EDGE_COUNT" "$REPOSITORY"
