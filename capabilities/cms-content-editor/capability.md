# CMS Content Editor

## Capability

Apply explicit CMS document create or update requests from one queue issue.

The queue issue is keyed as `cms-content-edit-queue`. If it does not exist, create it and stop. Do not edit CMS content until a human adds a request comment.

Request comments must include one fenced JSON block tagged `cms-edit-request`:

```cms-edit-request
{
  "id": "stable-request-id",
  "operation": "update",
  "collection": "lessons",
  "documentId": "document-id",
  "data": {
    "title": "Updated title"
  },
  "reason": "Why this edit is wanted"
}
```

For creates, use `operation: "create"` and omit `documentId`:

```cms-edit-request
{
  "id": "stable-request-id",
  "operation": "create",
  "collection": "lessons",
  "data": {
    "title": "New lesson"
  },
  "reason": "Why this new document is wanted"
}
```

## Tick

1. Ensure the queue issue exists:
   `ensure_issue({ key: "cms-content-edit-queue", title: "CMS content edit queue", body: <queue body> })`.
2. Read the queue issue with `read_thread({ number: <queue issue number>, limit: 50 })`.
3. Find the oldest valid `cms-edit-request` comment whose `id` is not in `data.processedRequestIds` and not in `data.failedRequestIds`.
4. If no new request exists, call `submit_state` with the existing state and stop.
5. Check CMS availability with `cms_list_collections()`.
6. If the request uses human names for related records, resolve them with `cms_list_documents()` before writing. For example, find course/chapter ids by searching the `courses` and `chapters` collections. Do not ask the operator for ids until the CMS search tool has been tried and failed.
7. For `operation: "create"`, create the document with `cms_create_document({ collection, data })`.
8. For `operation: "update"` or a request without `operation`, read the current document with `cms_get_document({ collection, id: documentId })`, then update it with `cms_update_document({ collection, id: documentId, data })`.
9. Record one result comment with `ensure_comment`.
10. Add the request id to `processedRequestIds` on success, or `failedRequestIds` on failure, then call `submit_state`.

Queue issue body:

```md
{{mentions}} Add CMS edit requests as comments using this exact shape:

\```cms-edit-request
{
  "id": "stable-request-id",
  "operation": "update",
  "collection": "lessons",
  "documentId": "document-id",
  "data": {
    "title": "Updated title"
  },
  "reason": "Why this edit is wanted"
}
\```

Kody applies one unprocessed request per tick.

For a new document, set `"operation": "create"` and omit `"documentId"`.
```

## Restrictions

- For updates, update only the fields present in `data`.
- For creates, create only one document from the explicit queued `data`.
- Do not delete documents.
- Do not invent edits, rewrite content, or change a document without a queued request.
- Do not process a request without `id`, `collection`, and object `data`.
- Do not process an update request without `documentId`.
- Do not use Bash, Node scripts, MongoDB packages, direct database URLs, repository files, or inferred ids for CMS content. CMS tools are the only source of truth.
- If the CMS tool returns an auth, permission, write-policy, or validation error, record the failure and stop.
- Never include secrets or tokens in comments.

## State

Keep this state shape:

```json
{
  "cursor": "idle",
  "data": {
    "queueIssue": 0,
    "processedRequestIds": [],
    "failedRequestIds": []
  },
  "done": false
}
```
