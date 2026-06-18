# Resolution

Kody store assets are shared defaults. Local repo assets are overrides.

Resolution order:

1. Local `.kody/duties/<slug>`, `.kody/executables/<slug>`, or
   `.kody/staff/<slug>.md`
2. Store `.kody/duties/<slug>`, `.kody/executables/<slug>`, or
   `.kody/staff/<slug>.md`
3. Engine built-ins

The store does not own repo-specific state, runs, sessions, secrets, reports, or
goals.

