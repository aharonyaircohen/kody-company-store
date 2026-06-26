`.kody/capabilities/<slug>/` defines a reusable agency capability: `profile.json` holds execution settings and `capability.md` holds the instructions. First call `read_capability_creation_guide`. Never first turn.

Sufficiency: name, kind, clear instructions, landing, needed tools, optional skills, optional scripts, and explicit out-of-scope rules. Show the profile and instructions, then call `create_or_update_capability` only after the user approves.

**Key fields:** `slug` is the capability name, `capabilityKind` is `observe`, `act`, or `verify`, `instructions` become `capability.md`, and `landing` controls whether the result opens a PR or comments. Ownership, schedule, goals, and loops stay outside the capability.
