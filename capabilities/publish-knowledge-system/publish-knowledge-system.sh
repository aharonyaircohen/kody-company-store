set -euo pipefail

ARTIFACT_DIR="${KODY_ARTIFACT_DIR:-$PWD/.kody-engine/artifacts/knowledge-system}"
GRAPH_FILE="$ARTIFACT_DIR/graph.json"
REPORT_FILE="$ARTIFACT_DIR/report.md"
META_FILE="$ARTIFACT_DIR/meta.json"
for file in "$GRAPH_FILE" "$REPORT_FILE" "$META_FILE"; do [[ -s "$file" ]] || { printf 'FAILED: artifact missing: %s\n' "$file"; exit 1; }; done

REPOSITORY="$(jq -r .repository "$META_FILE")"
OWNER="${REPOSITORY%%/*}"
REPO="${REPOSITORY#*/}"
AUTH_TOKEN="${KODY_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
[[ -n "$AUTH_TOKEN" ]] || { printf 'FAILED: Kody or GitHub token is required\n'; exit 1; }
KODY_DASHBOARD_URL="${KODY_DASHBOARD_URL:-https://kody-dashboard-khaki.vercel.app}"
KODY_DASHBOARD_URL="${KODY_DASHBOARD_URL%/}"
auth_args=(-H "x-kody-token: $AUTH_TOKEN" -H "x-kody-owner: $OWNER" -H "x-kody-repo: $REPO")

upload_file() {
  local file="$1" content_type="$2" upload_url
  upload_url="$(curl --fail --silent --show-error -X POST "${auth_args[@]}" "$KODY_DASHBOARD_URL/api/kody/knowledge-system" | jq -er .uploadUrl)"
  curl --fail --silent --show-error -X POST -H "Content-Type: $content_type" --data-binary "@$file" "$upload_url" | jq -er .storageId
}

GRAPH_STORAGE_ID="$(upload_file "$GRAPH_FILE" application/json)"
REPORT_STORAGE_ID="$(upload_file "$REPORT_FILE" 'text/markdown; charset=utf-8')"
publish_body="$(jq -nc --arg graphStorageId "$GRAPH_STORAGE_ID" --arg reportStorageId "$REPORT_STORAGE_ID" --slurpfile meta "$META_FILE" '{graphStorageId: $graphStorageId, reportStorageId: $reportStorageId, generatedAt: $meta[0].generatedAt, sourceRevision: $meta[0].sourceRevision, nodeCount: $meta[0].nodeCount, edgeCount: $meta[0].edgeCount, schemaVersion: 1}')"
curl --fail --silent --show-error -X PUT "${auth_args[@]}" -H "Content-Type: application/json" --data "$publish_body" "$KODY_DASHBOARD_URL/api/kody/knowledge-system" | jq -e '.ok == true' >/dev/null

printf 'DONE\nCOMMIT_MSG: chore(knowledge): publish knowledge system\nPR_SUMMARY:\n- Published the Knowledge System artifacts for %s.\n' "$REPOSITORY"
