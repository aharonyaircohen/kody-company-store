# Task Memorize

## Job

Turn task and execution experience into durable `.kody/memory/` entries.

## AgentAction

Run the `task-memorize` agentAction. Its skill owns the detailed method and runtime state handling.

## Output

New or updated memory files and index entries when high-confidence lessons exist.

## Allowed Commands

- Run the `task-memorize` agentAction.

## Restrictions

- Never edit the source task recommendation file.
- Do not promote weak or speculative lessons.
- Use memorization markers to avoid duplicates.
- Do not overwrite reserved memory filenames.
