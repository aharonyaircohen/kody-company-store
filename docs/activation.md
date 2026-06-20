# Activation

The store is a catalog. It is not an auto-run list.

Consumer repos decide which shared company model they activate. Store duties and
goals are inactive by default until the consumer opts in from `kody.config.json`.

```json
{
  "company": {
    "activeDuties": ["release"],
    "activeGoals": ["web-release"]
  }
}
```

## Duties

A store duty is an available standing responsibility.

The duty may declare `every`, `staff`, and `executable`, but those fields do not
make it run in every repo. They are used only after the consumer lists the duty
under `company.activeDuties`.

Rules:

- Missing `company.activeDuties` means no store duties auto-run.
- Empty `company.activeDuties` means no store duties auto-run.
- Local repo duties remain repo-owned and can run from the local repo.
- Do not add `disabled: true` to all store duties. Activation belongs to the
  consumer, not the catalog item.

## Goals

Store goals are inactive templates. Consumer repos may also define local goal templates.
Templates live under `.kody/goals/templates/<slug>/state.json`; live runs live under
`.kody/goals/instances/<id>/state.json`.

The consumer activates a goal through `company.activeGoals`, then creates or updates
a runtime goal instance with repo facts such as `facts.issue`. Missing or empty
`company.activeGoals` means no store goals auto-run.

Store goals must not contain repo-specific runtime history. Runtime goal progress
belongs in the consumer repo's `kody-state` branch.

## Mental Model

```text
kody-store = menu
consumer repo = decides what is enabled
duty = available responsibility
goal = available outcome template
activation = permission to run
```
