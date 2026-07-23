def agency_id($kind; $id): "kody:agency:" + $kind + ":" + $id;
def run_id($id): "kody:run:" + $id;
def output_id($id): "kody:output:" + $id;
def issue_id($number): "github:issue:" + ($number | tostring);
def pr_id($number): "github:pr:" + ($number | tostring);
def ref_id($ref): agency_id($ref.kind; $ref.id);
def generic_key($row):
  ($row.slug // $row.intentId // $row.goalId // $row.workflowId //
   $row.journeyId // $row.runId // $row.recordId // $row.taskKey //
   $row.entryId // $row.macroId // $row._id // "record") | tostring;
def generic_label($row; $fallback):
  ($row.title // $row.name // $row.label // $row.slug // $row.summary //
   $fallback) | tostring;
def generic_domain($table):
  if ($table | test("intent|goal"; "i")) then "business"
  elif ($table | test("agent|capability|workflow|agency|macro"; "i")) then "agency"
  elif ($table | test("journey"; "i")) then "quality"
  elif ($table | test("run|task|inbox"; "i")) then "work"
  elif ($table | test("report|manifest|definition|catalog"; "i")) then "knowledge"
  else "other" end;

. as $input |
($input.backend.tables // {}) as $tables |
([$tables.agencyDefinitions[]?]
  | sort_by(.kind, .data.id, .createdAt, .recordId)
  | group_by(.kind, .data.id)
  | map(last)) as $definitions |
([$tables.agencyStates[]?]) as $states |
([$tables.agencyRuns[]?]) as $runs |
([$tables.agencyOutputs[]?]) as $outputs |
def state_for($kind; $id):
  first($states[] | select(.kind == $kind and .definitionId == $id)) // null;
def definition_label($definition):
  ($definition.data.name // $definition.data.direction //
   $definition.data.objective.desiredState // $definition.data.action //
   $definition.data.role // $definition.data.id) | tostring;
def definition_domain($kind):
  if $kind == "intent" or $kind == "operation" or
     $kind == "goal" or $kind == "loop"
  then "business"
  else "agency"
  end;
def selected_tables: [
  "definitionHeads", "definitionVersions", "catalog", "workflows",
  "workflowRuns", "userJourneys", "userJourneyVersions", "userJourneyRuns",
  "intents", "intentDecisions", "goals", "reports", "agents", "macros",
  "agencyRecords", "taskState", "capabilityState", "dailyLogs",
  "runEvents", "manifests", "inboxEntries"
];

([selected_tables[] as $table |
  ($tables[$table] // [])[] as $row |
  (generic_key($row)) as $key |
  {
    id: ("kody:" + $table + ":" + $key),
    label: generic_label($row; $key),
    type: $table,
    domain: generic_domain($table),
    description: (($row.status // $row.state // $row.kind // "") | tostring),
    source: "kody"
  }
]) as $generic_nodes |
([$definitions[] |
  (state_for(.kind; .data.id)) as $state |
  {
    id: agency_id(.kind; .data.id),
    label: definition_label(.),
    type: .kind,
    domain: definition_domain(.kind),
    description: (($state.data.lifecycle // .data.responsibility //
      .data.objective.desiredState // "") | tostring),
    source: "kody"
  }
]) as $definition_nodes |
([$runs[] |
  {
    id: run_id(.runId),
    label: ((.run.title // .run.action // .runId) | tostring),
    type: "run",
    domain: "work",
    description: ((.run.status // "") | tostring),
    source: "kody"
  }
]) as $run_nodes |
([$outputs[] |
  {
    id: output_id(.recordId),
    label: ((.data.key // .recordId) | tostring),
    type: ((.data.kind // "output") | tostring),
    domain: "knowledge",
    description: ((.data.contract // "") | tostring),
    source: "kody"
  }
]) as $output_nodes |
([($input.issues // [])[] |
  {
    id: issue_id(.number),
    label: .title,
    type: "issue",
    domain: "work",
    description: .state,
    resource: .url,
    source: "github"
  }
]) as $issue_nodes |
([($input.prs // [])[] |
  {
    id: pr_id(.number),
    label: .title,
    type: "pull_request",
    domain: "work",
    description: .state,
    resource: .url,
    source: "github"
  }
]) as $pr_nodes |
($generic_nodes + $definition_nodes + $run_nodes + $output_nodes +
 $issue_nodes + $pr_nodes) as $nodes |
([
  $definitions[] |
  if .kind == "operation" then
    . as $operation |
    $operation.data.intentIds[]? |
    {
      source: agency_id("intent"; .),
      target: agency_id("operation"; $operation.data.id),
      relation: "delegates",
      confidence: "EXTRACTED"
    }
  elif .kind == "goal" then
    {
      source: agency_id("operation"; .data.operationId),
      target: agency_id("goal"; .data.id),
      relation: "owns",
      confidence: "EXTRACTED"
    },
    {
      source: agency_id("goal"; .data.id),
      target: ref_id(.data.executionRef),
      relation: "executes",
      confidence: "EXTRACTED"
    }
  elif .kind == "loop" then
    {
      source: agency_id("operation"; .data.operationId),
      target: agency_id("loop"; .data.id),
      relation: "owns",
      confidence: "EXTRACTED"
    },
    {
      source: agency_id("loop"; .data.id),
      target: ref_id(.data.targetRef),
      relation: "triggers",
      confidence: "EXTRACTED"
    }
  elif .kind == "workflow" then
    . as $workflow |
    $workflow.data.steps[]? |
    {
      source: agency_id("workflow"; $workflow.data.id),
      target: ref_id(.capabilityRef),
      relation: "uses",
      confidence: "EXTRACTED"
    }
  else empty end
]) as $definition_edges |
([$runs[] |
  . as $run |
  ($run.run.trace // [])[]? |
  {
    source: ref_id(.),
    target: run_id($run.runId),
    relation: "participates-in",
    confidence: "EXTRACTED"
  }
]) as $run_edges |
([$outputs[] |
  {
    source: run_id(.runId),
    target: output_id(.recordId),
    relation: "produces",
    confidence: "EXTRACTED"
  }
]) as $output_edges |
([($input.prs // [])[] |
  . as $pr |
  (.closingIssuesReferences // [])[]? |
  {
    source: issue_id(.number),
    target: pr_id($pr.number),
    relation: "resolved-by",
    confidence: "EXTRACTED"
  }
]) as $github_edges |
{
  nodes: ([{
    id: ("repo:" + $input.repository),
    label: $input.repository,
    type: "repository",
    domain: "project",
    source: "github"
  }] + $nodes | unique_by(.id)),
  edges: (
    ([$nodes[] | {
      source: ("repo:" + $input.repository),
      target: .id,
      relation: "contains",
      confidence: "EXTRACTED"
    }] + $definition_edges + $run_edges + $output_edges + $github_edges)
    | unique_by(.source, .target, .relation)
  )
}
