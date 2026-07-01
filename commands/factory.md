---
description: Create review-ready Kody model definitions
argument-hint: <model request>
---
Create a Kody agent-factory request for: $ARGUMENTS

This slash command is explicit approval to create the request issue and dispatch the factory review flow.

Steps:
1. Create a GitHub issue that preserves the operator request and asks Kody to generate review-ready agency model definitions.
2. Call `kody_run_issue` for that issue with `capability: "agent-factory"`.
3. Tell the operator the issue URL and that agent-factory will return a state-repo PR for review.

Boundaries:
- Do not create or edit model files directly in chat.
- Do not open a consumer-repo PR.
- Do not activate generated definitions.
- The generated bundle must go through the configured state repo PR review boundary.
