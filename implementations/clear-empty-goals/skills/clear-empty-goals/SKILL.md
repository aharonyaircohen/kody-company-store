---
name: clear-empty-goals
description: Find goals that contain no tasks and remove or report them according to the implementation method.
---

# Clear Empty Goals Skill

Use this skill when the `clear-empty-goals` implementation runs from the matching capability.

Runtime state is owned by the engine. Do not ask the capability author to configure raw state keys.

## Method

Remove only goals that have no tasks. If task ownership or state is ambiguous,
report the goal and leave it unchanged.
