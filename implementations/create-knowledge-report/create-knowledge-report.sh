set -euo pipefail

ARTIFACT_DIR="${KODY_ARTIFACT_DIR:-$PWD/.kody-engine/artifacts/knowledge-system}"
META="$ARTIFACT_DIR/meta.json"
[[ -s "$ARTIFACT_DIR/graph.json" && -s "$META" ]] || { printf 'FAILED: knowledge graph artifact is missing\n'; exit 1; }

jq -r '
  "# Knowledge System\n\n" +
  "- Repository: `" + .repository + "`\n" +
  "- Generated: `" + .generatedAt + "`\n" +
  "- Source revision: `" + .sourceRevision + "`\n" +
  "- Nodes: " + (.nodeCount | tostring) + "\n" +
  "- Edges: " + (.edgeCount | tostring) + "\n" +
  "- Kody business records: " + (.kodyCount | tostring) + "\n" +
  "- GitHub issues: " + (.issueCount | tostring) + "\n" +
  "- GitHub pull requests: " + (.prCount | tostring)
' "$META" >"$ARTIFACT_DIR/report.md"

printf 'DONE\nCOMMIT_MSG: chore(knowledge): create knowledge report\nPR_SUMMARY:\n- Created the Knowledge System report artifact.\n'
