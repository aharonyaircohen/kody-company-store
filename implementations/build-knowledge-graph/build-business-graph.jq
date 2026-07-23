def agency_id($kind; $id): "kody:agency:" + $kind + ":" + $id;
def agent_id($id): "kody:agent:" + $id;
def run_id($id): "kody:run:" + $id;
def output_id($id): "kody:output:" + $id;
def record_id($id): "kody:agencyRecords:" + $id;
def report_id($slug): "kody:report:" + $slug;
def repo_doc_id($kind): "kody:repoDocs:" + $kind;
def task_state_id($row): "kody:task:" + $row.taskKey + ":" + $row.kind;
def issue_id($number): "github:issue:" + ($number | tostring);
def pr_id($number): "github:pr:" + ($number | tostring);
def ref_id($ref):
  if $ref.kind == "agent" then agent_id($ref.id)
  else agency_id($ref.kind; $ref.id)
  end;
def edge($source; $relation; $target): {
  source: $source,
  target: $target,
  relation: $relation,
  confidence: "EXTRACTED"
};
def definition_domain($kind):
  if $kind == "intent" or $kind == "goal" then "business"
  elif $kind == "agent" then "agency"
  else "execution"
  end;
def definition_label($definition):
  ($definition.data.name // $definition.data.direction //
   $definition.data.objective.desiredState // $definition.data.action //
   $definition.data.role // $definition.data.id) | tostring;
def task_target_id($row):
  if ($row.taskKey | startswith("prs/")) then
    pr_id($row.taskKey | sub("^prs/"; ""))
  elif ($row.taskKey | startswith("issues/")) then
    issue_id($row.taskKey | sub("^issues/"; ""))
  elif $row.doc.taskType? == "pr" then
    pr_id($row.doc.taskId // $row.taskKey)
  else
    issue_id($row.doc.taskId? // $row.taskKey)
  end;
def has_content($value):
  $value != null and $value != "" and $value != [] and $value != {};
def repo_doc_is_visible($row):
  $row.kind | test("^(context:|todo:|notes?:|instructions$|system-prompt$)");
def repo_doc_type($kind):
  if ($kind | startswith("context:")) then "context"
  elif ($kind | startswith("todo:")) then "todo"
  elif ($kind | test("^notes?:")) then "note"
  else "document"
  end;
def repo_doc_domain($kind):
  if ($kind | startswith("todo:")) then "work" else "knowledge" end;
def repo_doc_label($row):
  if ($row.doc | type) == "object" then
    ($row.doc.title // $row.doc.name // ($row.kind | sub("^[^:]+:"; "")))
  elif $row.kind == "instructions" then "Project instructions"
  elif $row.kind == "system-prompt" then "System prompt"
  else $row.kind
  end | tostring;
def repo_doc_relation($kind):
  if ($kind | startswith("todo:")) then "tracks"
  elif ($kind | startswith("context:")) then "has-context"
  else "documents"
  end;

. as $input |
($input.backend.tables // {}) as $tables |
([$tables.agencyDefinitions[]?]
  | sort_by(.kind, .data.id, .createdAt, .recordId)
  | group_by(.kind, .data.id)
  | map(last)) as $definitions |
([$tables.agencyStates[]?]) as $states |
([$tables.agencyRuns[]?]
  | sort_by(
      (.subjectType // .run.subjectType // ""),
      (.subjectId // .run.subjectId // ""),
      (.updatedAt // .run.updatedAt // ""),
      .runId
    )
  | group_by(
      (.subjectType // .run.subjectType // "") + ":" +
      (.subjectId // .run.subjectId // .runId)
    )
  | map(last)) as $runs |
([$tables.agencyOutputs[]?]) as $all_outputs |
([$tables.agencyRecords[]?]) as $all_records |
([$all_records[]
  | select(.kind == "observation")]
  | sort_by((.doc.subject // .recordId), (.updatedAt // .doc.observedAt // ""))
  | group_by(.doc.subject // .recordId)
  | map(last)) as $latest_observations |
(
  [$all_records[] | select(.kind != "observation")] + $latest_observations
  | unique_by(.kind, .recordId)
) as $records |
([$tables.reports[]?]
  | sort_by(.slug, .updatedAt, (.runId // ""))
  | group_by(.slug)
  | map(last)) as $reports |
([$tables.repoDocs[]?] | map(select(repo_doc_is_visible(.)))) as $repo_docs |
([$tables.taskState[]?] | map(select(has_content(.doc)))) as $task_states |
def state_for($kind; $id):
  first($states[] | select(.kind == $kind and .definitionId == $id)) // null;

([$definitions[] |
  (state_for(.kind; .data.id)) as $state |
  {
    id: ref_id({kind: .kind, id: .data.id}),
    label: definition_label(.),
    type: .kind,
    domain: definition_domain(.kind),
    description: (($state.data.lifecycle // .data.responsibility //
      .data.objective.desiredState // .data.purpose // "") | tostring),
    source: "kody"
  }
]) as $definition_nodes |
(
  [$tables.agents[]? | {
    id: agent_id(.slug),
    label: ((.frontmatter.name // .frontmatter.title // .slug) | tostring),
    type: "agent",
    domain: "agency",
    description: ((.frontmatter.description // .frontmatter.role // "") | tostring),
    source: "kody"
  }] +
  [$definitions[] |
    select(.kind == "implementation") |
    .data.agentRef? |
    select(.kind == "agent") |
    {
      id: agent_id(.id),
      label: .id,
      type: "agent",
      domain: "agency",
      source: "kody"
    }
  ] | unique_by(.id)
) as $agent_nodes |
([$runs[] | {
  id: run_id(.runId),
  label: ((.run.title // .run.subjectLabel // .run.action // .runId) | tostring),
  type: "run",
  domain: "work",
  description: ((.run.status // "") | tostring),
  resource: .run.detailUrl,
  source: "kody"
}]) as $run_nodes |
([$all_outputs[] |
  . as $output |
  select(any($runs[]; .runId == $output.runId)) |
  {
    id: output_id(.recordId),
    label: ((.data.key // .recordId) | tostring),
    type: ((.data.kind // "output") | tostring),
    domain: "knowledge",
    description: ((.data.contract // "") | tostring),
    source: "kody"
  }
]) as $output_nodes |
([$records[] | {
  id: record_id(.recordId),
  label: ((.doc.title // .doc.summary // .doc.actual // .recordId) | tostring),
  type: .kind,
  domain: "knowledge",
  description: ((.doc.status // .doc.phase // .kind) | tostring),
  source: "kody"
}]) as $record_nodes |
([$reports[] | {
  id: report_id(.slug),
  label: ((.title // .slug) | tostring),
  type: "report",
  domain: "knowledge",
  description: ((.meta.status // .meta.reportType // "") | tostring),
  source: "kody"
}]) as $report_nodes |
([$repo_docs[] | {
  id: repo_doc_id(.kind),
  label: repo_doc_label(.),
  type: repo_doc_type(.kind),
  domain: repo_doc_domain(.kind),
  description: .kind,
  source: "kody"
}]) as $repo_doc_nodes |
([$task_states[] | {
  id: task_state_id(.),
  label: (
    if (.doc | type) == "object"
    then (.doc.title // .doc.summary // (.kind + " · " + .taskKey))
    else (.kind + " · " + .taskKey)
    end | tostring
  ),
  type: (if .kind == "followups" then "todo" else .kind end),
  domain: "work",
  description: .kind,
  source: "kody"
}]) as $task_nodes |
([($input.prs // [])[] |
  (.closingIssuesReferences // [])[]?.number
] | unique) as $linked_issue_numbers |
([($input.issues // [])[] |
  . as $issue |
  select(
    $issue.state == "OPEN" or
    ($linked_issue_numbers | index($issue.number)) != null
  ) |
  {
  id: issue_id(.number),
  label: .title,
  type: "issue",
  domain: "work",
  description: .state,
  resource: .url,
  source: "github"
}]) as $issue_nodes |
([($input.prs // [])[] | {
  id: pr_id(.number),
  label: .title,
  type: "pull_request",
  domain: "work",
  description: .state,
  resource: .url,
  source: "github"
}]) as $pr_nodes |
([($input.code.nodes // [])[]?.source_file
  | select(type == "string" and length > 0)
  | split("/")
  | if length > 1 and (.[0] == "apps" or .[0] == "packages")
    then .[0] + "/" + .[1]
    else .[0]
    end
] | unique | map({
  id: ("project:area:" + .),
  label: .,
  type: "code_area",
  domain: "technical",
  description: "Repository area",
  source: "graphify"
})) as $code_area_nodes |
(
  [{
    id: ("repo:" + $input.repository),
    label: $input.repository,
    type: "repository",
    domain: "project",
    source: "github"
  }] +
  $definition_nodes + $agent_nodes + $run_nodes + $output_nodes +
  $record_nodes + $report_nodes + $repo_doc_nodes + $task_nodes +
  $issue_nodes + $pr_nodes + $code_area_nodes
  | unique_by(.id)
) as $nodes |
([$definitions[] |
  if .kind == "operation" then
    . as $operation |
    $operation.data.intentIds[]? |
    edge(
      agency_id("intent"; .);
      "delegates";
      agency_id("operation"; $operation.data.id)
    )
  elif .kind == "goal" then
    edge(
      agency_id("operation"; .data.operationId);
      "owns";
      agency_id("goal"; .data.id)
    ),
    edge(
      agency_id("goal"; .data.id);
      "executes";
      ref_id(.data.executionRef)
    )
  elif .kind == "loop" then
    edge(
      agency_id("operation"; .data.operationId);
      "owns";
      agency_id("loop"; .data.id)
    ),
    edge(
      agency_id("loop"; .data.id);
      "triggers";
      ref_id(.data.targetRef)
    )
  elif .kind == "workflow" then
    . as $workflow |
    $workflow.data.steps[]? |
    edge(
      agency_id("workflow"; $workflow.data.id);
      "uses";
      ref_id(.capabilityRef)
    )
  else empty
  end
]) as $definition_edges |
([$definitions[] |
  select(.kind == "implementation") |
  . as $implementation |
  edge(
    ref_id($implementation.data.capabilityRef);
    "implemented-by";
    agency_id("implementation"; $implementation.data.id)
  ),
  (
    $implementation.data.agentRef? |
    select(.kind == "agent") |
    edge(
      agency_id("implementation"; $implementation.data.id);
      "run-by";
      agent_id(.id)
    )
  )
]) as $implementation_edges |
([$runs[] |
  (.subjectType // .run.subjectType) as $kind |
  (.subjectId // .run.subjectId) as $id |
  select($kind != null and $id != null) |
  edge(ref_id({kind: $kind, id: $id}); "has-run"; run_id(.runId))
]) as $run_edges |
([$all_outputs[] |
  . as $output |
  select(any($runs[]; .runId == $output.runId)) |
  edge(run_id(.runId); "produces"; output_id(.recordId))
]) as $output_edges |
([$records[] |
  . as $record |
  if .kind == "observation" then
    .doc.capability? |
    select(type == "string" and length > 0) |
    edge(
      agency_id("capability"; .);
      "produces";
      record_id($record.recordId)
    )
  elif .kind == "finding" then
    (
      .doc.observationIds[]? |
      edge(record_id(.); "evidence-for"; record_id($record.recordId))
    ),
    (
      .doc.learningIds[]? |
      edge(record_id($record.recordId); "produces-learning"; record_id(.))
    )
  elif .kind == "learning" then
    .doc.findingId? |
    select(type == "string" and length > 0) |
    edge(record_id(.); "produces-learning"; record_id($record.recordId))
  else empty
  end
]) as $record_edges |
([$task_states[] |
  edge(
    task_target_id(.);
    (if .kind == "followups" then "has-todo" else "has-" + .kind end);
    task_state_id(.)
  )
]) as $task_edges |
([$reports[] |
  . as $report |
  ($report.meta.capabilitySlug // $report.slug) as $capability |
  edge(
    agency_id("capability"; $capability);
    "produces";
    report_id($report.slug)
  )
]) as $report_edges |
([($input.prs // [])[] |
  . as $pr |
  (.closingIssuesReferences // [])[]? |
  edge(issue_id(.number); "resolved-by"; pr_id($pr.number))
]) as $github_edges |
(
  [$definitions[] |
    select(.kind == "intent") |
    edge(
      "repo:" + $input.repository;
      "pursues";
      agency_id("intent"; .data.id)
    )
  ] +
  [$agent_nodes[] |
    edge("repo:" + $input.repository; "has-agent"; .id)
  ] +
  [$issue_nodes[] |
    select(.description == "OPEN") |
    edge("repo:" + $input.repository; "tracks"; .id)
  ] +
  [$reports[] |
    edge("repo:" + $input.repository; "has-report"; report_id(.slug))
  ] +
  [$repo_docs[] |
    edge(
      "repo:" + $input.repository;
      repo_doc_relation(.kind);
      repo_doc_id(.kind)
    )
  ] +
  [$code_area_nodes[] |
    edge("repo:" + $input.repository; "has-area"; .id)
  ]
) as $repository_edges |
([$nodes[].id] | unique) as $node_ids |
(
  ($definition_edges + $implementation_edges + $run_edges + $output_edges +
   $record_edges + $task_edges + $report_edges + $github_edges +
   $repository_edges)
  | unique_by(.source, .target, .relation)
  | map(
      .source as $source |
      .target as $target |
      select(
        ($node_ids | index($source)) != null and
        ($node_ids | index($target)) != null and
        $source != $target
      )
    )
) as $edges |
([$edges[] | .source, .target] | unique) as $connected_node_ids |
{
  nodes: [
    $nodes[] |
    . as $node |
    select(($connected_node_ids | index($node.id)) != null)
  ],
  edges: $edges
}
