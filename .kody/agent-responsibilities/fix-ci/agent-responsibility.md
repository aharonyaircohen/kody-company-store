# PR CI Fix

## Job

Repair failing CI on an existing pull request.

## AgentAction

Run the `fix-ci` agentAction. Its CI repair skill owns the detailed method.

## Output

Updated commits on the pull request branch with CI repair evidence.

## Allowed Commands

- Run the `fix-ci` agentAction.

## Restrictions

- Only change what is needed to repair CI.
- Do not rewrite unrelated PR behavior.
- Do not claim success without checking the relevant CI failure.
