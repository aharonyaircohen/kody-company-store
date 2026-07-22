# Knowledge System refresh

Builds one current knowledge graph for the active consumer repository and
publishes it to Kody's repository-scoped Knowledge System storage.

The graph combines:

- repository code and structure from Graphify
- selected Kody business and operational records
- GitHub issues and pull requests

Raw conversations, chat events, attachments, secrets, and global records are
not added to the graph.

This is an Observe capability. It does not change repository source, issues,
pull requests, or Kody business records.
