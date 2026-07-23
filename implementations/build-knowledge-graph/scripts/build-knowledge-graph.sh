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
BUSINESS_FILTER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../build-business-graph.jq"
ARTIFACT_DIR="${KODY_ARTIFACT_DIR:-$PWD/.kody-engine/artifacts/knowledge-system}"

auth_args=(
  -H "x-kody-token: $AUTH_TOKEN"
  -H "x-kody-owner: $OWNER"
  -H "x-kody-repo: $REPO"
)

# Reliable CI base: deterministic local AST extraction with no model or API key.
uvx --from graphifyy==0.9.18 graphify extract . \
  --code-only \
  --no-cluster \
  --out "$GRAPHIFY_DIR" >/dev/null

BASE_GRAPH="$GRAPHIFY_DIR/graphify-out/graph.json"
[[ -s "$BASE_GRAPH" ]] || fail "Graphify did not produce graph.json"

curl --fail --silent --show-error \
  "${auth_args[@]}" \
  "$KODY_DASHBOARD_URL/api/kody/company/backend/export?scope=knowledge-graph" \
  >"$EXPORT_FILE"

gh issue list --repo "$REPOSITORY" --state all --limit 500 \
  --json number,title,state,labels,assignees,milestone,url,createdAt,updatedAt \
  >"$ISSUES_FILE"
gh pr list --repo "$REPOSITORY" --state all --limit 500 \
  --json number,title,state,isDraft,baseRefName,headRefName,labels,author,url,createdAt,updatedAt,closingIssuesReferences \
  >"$PRS_FILE"

# Only business and operational tables enter the graph. Raw chat data is
# intentionally excluded: conversationEntries, conversationTurns, chatEvents,
# conversationAttachments, and all user-private/global state stay out.
jq -n \
  --arg repository "$REPOSITORY" \
  --slurpfile backend "$EXPORT_FILE" \
  --slurpfile issues "$ISSUES_FILE" \
  --slurpfile prs "$PRS_FILE" \
  --slurpfile code "$BASE_GRAPH" \
  '{repository: $repository, backend: $backend[0], issues: $issues[0], prs: $prs[0], code: $code[0]}' |
  jq -f "$BUSINESS_FILTER" >"$BUSINESS_FILE"

NODE_COUNT="$(jq '.nodes | length' "$BUSINESS_FILE")"
EDGE_COUNT="$(jq '.edges | length' "$BUSINESS_FILE")"
GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
SOURCE_REVISION="$(git rev-parse HEAD)"
KODY_COUNT="$(jq '[.nodes[] | select(.source == "kody")] | length' "$BUSINESS_FILE")"
ISSUE_COUNT="$(jq '[.nodes[] | select(.type == "issue")] | length' "$BUSINESS_FILE")"
PR_COUNT="$(jq '[.nodes[] | select(.type == "pull_request")] | length' "$BUSINESS_FILE")"

mkdir -p "$ARTIFACT_DIR"
cp "$BUSINESS_FILE" "$ARTIFACT_DIR/graph.json"
cp "$BASE_GRAPH" "$ARTIFACT_DIR/technical-graph.json"
jq -nc \
  --arg repository "$REPOSITORY" \
  --arg generatedAt "$GENERATED_AT" \
  --arg sourceRevision "$SOURCE_REVISION" \
  --argjson nodeCount "$NODE_COUNT" \
  --argjson edgeCount "$EDGE_COUNT" \
  --argjson kodyCount "$KODY_COUNT" \
  --argjson issueCount "$ISSUE_COUNT" \
  --argjson prCount "$PR_COUNT" \
  '{
    repository: $repository,
    generatedAt: $generatedAt,
    sourceRevision: $sourceRevision,
    nodeCount: $nodeCount,
    edgeCount: $edgeCount,
    kodyCount: $kodyCount,
    issueCount: $issueCount,
    prCount: $prCount
  }' >"$ARTIFACT_DIR/meta.json"

printf 'DONE\nCOMMIT_MSG: chore(knowledge): build knowledge graph\nPR_SUMMARY:\n- Built %s nodes and %s edges for %s.\n' \
  "$NODE_COUNT" "$EDGE_COUNT" "$REPOSITORY"
